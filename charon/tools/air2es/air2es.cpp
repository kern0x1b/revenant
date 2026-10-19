#include <llvm/ADT/PostOrderIterator.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/DataLayout.h>
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/InstIterator.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/IntrinsicInst.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/raw_ostream.h>
#include <cmath>
#include <cstdio>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

using namespace llvm;

namespace {

const int LoopLimit = 64;

struct Failure {
    std::string message;
};

[[noreturn]] void fail(const std::string &message)
{
    throw Failure{message};
}

struct ArgInfo {
    std::string generated;
    unsigned index = 0;
    std::string kind;
    int location = -1;
    std::string typeName;
    std::string name;
    bool flat = false;
    bool optional = false;
    int size = 0;
};

struct Pointer {
    enum Kind { Buffer, Texture, Sampler } kind = Buffer;
    int binding = 0;
    uint64_t offset = 0;
    bool vertexIndexed = false;
    bool instanceIndexed = false;
    uint64_t stride = 0;
};

struct Value_ {
    std::string text;
    std::vector<std::string> fields;
    std::vector<std::string> comps;
    bool aggregate = false;
};

std::string stringOf(const MDOperand &operand)
{
    if (auto *s = dyn_cast_or_null<MDString>(operand.get()))
        return s->getString().str();
    return {};
}

bool intOf(const MDOperand &operand, int64_t &out)
{
    if (auto *c = dyn_cast_or_null<ConstantAsMetadata>(operand.get()))
        if (auto *i = dyn_cast<ConstantInt>(c->getValue())) {
            out = i->getSExtValue();
            return true;
        }
    return false;
}

ArgInfo parseArg(const MDNode *node, bool indexed)
{
    ArgInfo info;
    unsigned at = 0;
    int64_t number;
    if (indexed && node->getNumOperands() && intOf(node->getOperand(0), number)) {
        info.index = (unsigned)number;
        at = 1;
    }
    for (unsigned i = at; i < node->getNumOperands(); i++) {
        std::string s = stringOf(node->getOperand(i));
        if (s.empty())
            continue;
        if (s.rfind("generated(", 0) == 0) {
            info.generated = s;
        } else if (s == "air.location_index") {
            if (i + 1 < node->getNumOperands() && intOf(node->getOperand(i + 1), number))
                info.location = (int)number;
        } else if (s == "air.arg_type_name") {
            info.typeName = stringOf(node->getOperand(i + 1));
        } else if (s == "air.arg_name") {
            info.name = stringOf(node->getOperand(i + 1));
        } else if (s == "air.arg_type_size") {
            if (intOf(node->getOperand(i + 1), number))
                info.size = (int)number;
        } else if (s == "air.flat") {
            info.flat = true;
        } else if (s == "air.function_constant") {
            info.optional = true;
        } else if (s == "air.render_target" && info.kind.empty()) {
            info.kind = s;
            if (i + 1 < node->getNumOperands() && intOf(node->getOperand(i + 1), number))
                info.location = (int)number;
        } else if (s.rfind("air.", 0) == 0 && info.kind.empty() && s != "air.read" && s != "air.write" && s != "air.center" &&
                   s != "air.perspective" && s != "air.no_perspective" && s != "air.sample" && s != "air.buffer_size") {
            info.kind = s;
        }
    }
    return info;
}

struct Translator {
    Module &module;
    Function &function;
    bool vertex;
    const DataLayout &layout;
    std::vector<ArgInfo> args;
    std::vector<ArgInfo> outputs;
    std::map<const Value *, Value_> values;
    std::map<const Value *, Pointer> pointers;
    std::set<const Value *> vertexIds;
    std::vector<std::string> body;
    std::set<std::string> declared;
    std::vector<std::string> attributeDecls, uniformDecls, samplerDecls;
    std::vector<std::string> attributeJson, uniformJson, textureJson, samplerJson, varyingJson, sizeJson;
    std::map<int, std::string> textureNames;
    std::set<int> depthBindings, compareBindings, fetches;
    struct Loop {
        const BasicBlock *header = nullptr;
        std::set<const BasicBlock *> blocks;
        std::string brk, cont, index;
        std::map<const PHINode *, std::string> next;
    };
    std::vector<Loop> loops;
    std::map<const BasicBlock *, unsigned> loopOf;
    bool hoist = false;
    std::string indent = "    ";
    std::vector<std::string> declarations;
    std::map<const BasicBlock *, std::string> reach;
    std::map<const GlobalVariable *, std::string> globals;
    std::vector<std::string> constantJson;
    bool usesVertexId = false;
    bool usesInstanceId = false;
    bool usesFlip = false;
    bool usesTarget = false;
    bool usesDerivatives = false;
    bool usesOutput = false;
    std::vector<std::string> inputJson;
    std::set<const Value *> instanceIds;
    int counter = 0;

    Translator(Module &m, Function &f, bool v) : module(m), function(f), vertex(v), layout(m.getDataLayout()) {}

    static bool halfLike(Type *t)
    {
        return t->getScalarType()->isHalfTy();
    }

    std::string glslType(Type *t)
    {
        Type *scalar = t->getScalarType();
        unsigned n = 1;
        if (auto *v = dyn_cast<FixedVectorType>(t))
            n = v->getNumElements();
        std::string base;
        if (scalar->isHalfTy() || scalar->isFloatTy())
            base = n == 1 ? "float" : "vec";
        else if (scalar->isIntegerTy(1))
            base = n == 1 ? "bool" : "bvec";
        else if (scalar->isIntegerTy())
            base = n == 1 ? "int" : "ivec";
        else
        {
            std::string described;
            raw_string_ostream stream(described);
            t->print(stream);
            fail("type " + stream.str() + " has no GLSL ES 1.00 form");
        }
        if (n > 4)
            fail("vector wider than four components");
        return n == 1 ? base : base + std::to_string(n);
    }

    std::string qualified(Type *t)
    {
        return (halfLike(t) ? "mediump " : "") + glslType(t);
    }

    static std::string varyingName(const ArgInfo &info, unsigned fallback)
    {
        if (info.generated.empty())
            return "vary" + std::to_string(fallback);
        std::string s = "vary_";
        for (char c : info.generated)
            s += isalnum((unsigned char)c) ? c : '_';
        return s;
    }

    std::string fresh()
    {
        return "v" + std::to_string(counter++);
    }

    static std::string number(double d)
    {
        if (std::isinf(d) || std::isnan(d))
            fail("non-finite floating point constant");
        char buffer[64];
        snprintf(buffer, sizeof buffer, "%.9g", d);
        std::string s = buffer;
        if (s.find_first_of(".eE") == std::string::npos)
            s += ".0";
        return s;
    }

    std::string constant(const Constant *c)
    {
        Type *t = c->getType();
        if (isa<UndefValue>(c) || isa<PoisonValue>(c) || c->isNullValue()) {
            std::string type = glslType(t);
            std::string zero = t->getScalarType()->isIntegerTy(1) ? "false" : t->getScalarType()->isIntegerTy() ? "0" : "0.0";
            return isa<VectorType>(t) ? type + "(" + zero + ")" : zero;
        }
        if (auto *f = dyn_cast<ConstantFP>(c))
            return number(f->getValueAPF().convertToDouble());
        if (auto *i = dyn_cast<ConstantInt>(c)) {
            if (i->getBitWidth() == 1)
                return i->isOne() ? "true" : "false";
            return std::to_string(i->getSExtValue());
        }
        if (auto *v = dyn_cast<ConstantDataVector>(c)) {
            std::string s = glslType(t) + "(";
            for (unsigned i = 0; i < v->getNumElements(); i++)
                s += (i ? ", " : "") + constant(v->getElementAsConstant(i));
            return s + ")";
        }
        if (auto *v = dyn_cast<ConstantVector>(c)) {
            std::string s = glslType(t) + "(";
            for (unsigned i = 0; i < v->getNumOperands(); i++)
                s += (i ? ", " : "") + constant(cast<Constant>(v->getOperand(i)));
            return s + ")";
        }
        fail("constant of unsupported form");
    }

    Value_ &get(const Value *v)
    {
        auto it = values.find(v);
        if (it != values.end())
            return it->second;
        if (auto *c = dyn_cast<Constant>(v)) {
            Value_ r;
            r.text = constant(c);
            if (auto *vt = dyn_cast<FixedVectorType>(c->getType()))
                for (unsigned k = 0; k < vt->getNumElements(); k++)
                    r.comps.push_back(constant(c->getAggregateElement(k)));
            return values[v] = r;
        }
        fail("value used before definition");
    }

    std::vector<std::string> components(const Value *v)
    {
        Value_ &r = get(v);
        unsigned n = isa<FixedVectorType>(v->getType()) ? cast<FixedVectorType>(v->getType())->getNumElements() : 1;
        if (r.comps.size() == n)
            return r.comps;
        std::vector<std::string> out;
        for (unsigned k = 0; k < n; k++)
            out.push_back(n == 1 ? r.text : "(" + r.text + ")." + std::string(1, "xyzw"[k]));
        return out;
    }

    Value_ composed(Type *type, const std::vector<std::string> &comps)
    {
        Value_ r;
        r.comps = comps;
        r.text = glslType(type) + "(";
        for (size_t k = 0; k < comps.size(); k++)
            r.text += (k ? ", " : "") + comps[k];
        r.text += ")";
        return r;
    }

    std::string text(const Value *v)
    {
        return "(" + get(v).text + ")";
    }

    std::string temp(Type *type, const std::string &expr)
    {
        std::string name = fresh();
        if (hoist) {
            declarations.push_back("    " + qualified(type) + " " + name + ";");
            body.push_back(indent + name + " = " + expr + ";");
        } else {
            body.push_back("    " + qualified(type) + " " + name + " = " + expr + ";");
        }
        return name;
    }

    std::string define(const Instruction *i, const std::string &expr)
    {
        Value_ r;
        r.text = temp(i->getType(), expr);
        values[i] = r;
        return r.text;
    }

    void setup()
    {
        NamedMDNode *entries = module.getNamedMetadata(vertex ? "air.vertex" : "air.fragment");
        MDNode *entry = entries->getOperand(0);
        auto *outputList = dyn_cast<MDNode>(entry->getOperand(1));
        auto *argList = dyn_cast<MDNode>(entry->getOperand(2));
        if (outputList)
            for (auto &o : outputList->operands()) {
                ArgInfo info = parseArg(cast<MDNode>(o.get()), false);
                if (!vertex) {
                    int64_t n;
                    auto *node = cast<MDNode>(o.get());
                    if (node->getNumOperands() > 2 && intOf(node->getOperand(1), n))
                        info.location = (int)n;
                }
                outputs.push_back(info);
            }
        if (argList)
            for (auto &a : argList->operands())
                args.push_back(parseArg(cast<MDNode>(a.get()), true));
        unsigned position = 0;
        for (auto &arg : function.args()) {
            ArgInfo &info = args.at(position++);
            Value_ r;
            if (info.kind == "air.vertex_id") {
                usesVertexId = true;
                r.text = "int(a_vertex_id)";
                values[&arg] = r;
                vertexIds.insert(&arg);
            } else if (info.kind == "air.instance_id" && vertex) {
                usesInstanceId = true;
                r.text = "int(charon_instance)";
                values[&arg] = r;
                instanceIds.insert(&arg);
            } else if (info.kind == "air.vertex_input" && vertex) {
                std::string name = "vin" + std::to_string(info.location);
                Type *t = arg.getType();
                std::string declared = t->getScalarType()->isIntegerTy() ? (width(t) == 1 ? "float" : "vec" + std::to_string(width(t))) : glslType(t);
                attributeDecls.push_back("attribute highp " + declared + " " + name + ";");
                unsigned n = width(t);
                std::string scalar = t->getScalarType()->isHalfTy() ? "half" : t->getScalarType()->isFloatTy() ? "float" : "i" + std::to_string(t->getScalarType()->getIntegerBitWidth());
                inputJson.push_back("{\"name\":\"" + name + "\",\"location\":" + std::to_string(info.location) + ",\"scalar\":\"" + scalar + "\",\"components\":" + std::to_string(n) + ",\"optional\":" + (info.optional ? "true" : "false") + "}");
                if (t->getScalarType()->isIntegerTy())
                    r.text = n == 1 ? "int(" + name + " + 0.5)" : "ivec" + std::to_string(n) + "(" + name + " + 0.5)";
                else
                    r.text = name;
                values[&arg] = r;
            } else if (info.kind == "air.render_target" && !vertex) {
                std::set<int> written;
                for (auto &o : outputs)
                    if (o.kind == "air.render_target")
                        written.insert(o.location);
                if (info.location < 0 || info.location > 3)
                    fail("reading render target " + std::to_string(info.location) + " (there are four colour attachments)");
                if (glslType(arg.getType()) != "vec4")
                    fail("reading the colour attachment as a type that is not a four component float");
                if (written.size() == 1 && *written.begin() == info.location) {
                    r.text = "gl_LastFragData[0]";
                } else if (!written.count(info.location)) {
                    std::string name = "charon_attachment" + std::to_string(info.location);
                    fetches.insert(info.location);
                    r.text = "texture2D(" + name + ", gl_FragCoord.xy / charon_target)";
                } else {
                    fail("reading a colour attachment that the function writes together with others");
                }
                values[&arg] = r;
            } else if (info.kind == "air.front_facing" && !vertex) {
                r.text = "(gl_FrontFacing != (charon_flip < 0.0))";
                values[&arg] = r;
            } else if (info.kind == "air.point_coord" && !vertex) {
                r.text = "vec2(gl_PointCoord.x, 1.0 - gl_PointCoord.y)";
                values[&arg] = r;
            } else if (info.kind == "air.buffer") {
                Pointer p;
                p.kind = Pointer::Buffer;
                p.binding = info.location;
                pointers[&arg] = p;
            } else if (info.kind == "air.texture") {
                Pointer p;
                p.kind = Pointer::Texture;
                p.binding = info.location;
                pointers[&arg] = p;
                bool depthTexture = info.typeName.find("depth2d<") == 0;
                if (!depthTexture && info.typeName.find("texture2d<") != 0 && info.typeName.find("texture2d ") != 0)
                    fail("texture type " + info.typeName + " is not texture2d or depth2d");
                std::string name = "t" + std::to_string(info.location);
                if (!textureNames.count(info.location)) {
                    textureNames[info.location] = name;
                    if (depthTexture)
                        depthBindings.insert(info.location);
                }
            } else if (info.kind == "air.sampler") {
                Pointer p;
                p.kind = Pointer::Sampler;
                p.binding = info.location;
                pointers[&arg] = p;
            } else if (info.kind == "air.position") {
                                r.text = vertex ? "vec4(0.0)" : "vec4(gl_FragCoord.x, (charon_flip < 0.0 ? gl_FragCoord.y : charon_target.y - gl_FragCoord.y), gl_FragCoord.z, gl_FragCoord.w)";
                values[&arg] = r;
            } else if (info.kind == "air.fragment_input") {
                std::string name = varyingName(info, position - 1);
                std::string type = glslType(arg.getType());
                std::string declared = arg.getType()->isIntegerTy() ? "float" : type;
                std::string qualifier = std::string(halfLike(arg.getType()) ? "mediump " : "highp ");
                samplerDecls.push_back("varying " + qualifier + declared + " " + name + ";");
                varyingJson.push_back("{\"name\":\"" + name + "\",\"argument\":" + std::to_string(position - 1) + ",\"flat\":" + (info.flat ? "true" : "false") + "}");
                r.text = arg.getType()->isIntegerTy() ? (arg.getType()->isIntegerTy(1) ? "(" + name + " > 0.5)" : "int(" + name + " + 0.5)") : name;
                values[&arg] = r;
            } else {
                fail("argument kind " + info.kind + " is not supported for " + (vertex ? "vertex" : "fragment") + " shaders");
            }
        }
    }

    Pointer offsetPointer(const GetElementPtrInst *gep)
    {
        auto it = pointers.find(gep->getPointerOperand());
        if (it == pointers.end())
            fail("pointer arithmetic on an unknown base");
        Pointer p = it->second;
        Type *type = gep->getSourceElementType();
        bool first = true;
        for (auto index = gep->idx_begin(); index != gep->idx_end(); ++index) {
            const Value *v = index->get();
            if (first) {
                first = false;
                uint64_t size = layout.getTypeAllocSize(type);
                if (auto *c = dyn_cast<ConstantInt>(v)) {
                    p.offset += c->getSExtValue() * size;
                } else {
                    const Value *base = v;
                    while (auto *cast = dyn_cast<CastInst>(base))
                        base = cast->getOperand(0);
                    if (p.kind != Pointer::Buffer || p.vertexIndexed || p.instanceIndexed)
                        fail("buffer index that is not a vertex or instance identifier");
                    if (vertexIds.count(base))
                        p.vertexIndexed = true;
                    else if (instanceIds.count(base))
                        p.instanceIndexed = true;
                    else
                        fail("buffer index that is not a vertex or instance identifier");
                    p.stride = size;
                }
                continue;
            }
            auto *c = dyn_cast<ConstantInt>(v);
            if (!c)
                fail("dynamic index inside a buffer element");
            if (auto *s = dyn_cast<StructType>(type)) {
                p.offset += layout.getStructLayout(s)->getElementOffset((unsigned)c->getZExtValue());
                type = s->getElementType((unsigned)c->getZExtValue());
            } else if (auto *a = dyn_cast<ArrayType>(type)) {
                type = a->getElementType();
                p.offset += c->getZExtValue() * layout.getTypeAllocSize(type);
            } else if (auto *vt = dyn_cast<FixedVectorType>(type)) {
                type = vt->getElementType();
                p.offset += c->getZExtValue() * layout.getTypeAllocSize(type);
            } else {
                fail("index into a non-aggregate");
            }
        }
        return p;
    }

    std::string bufferLoad(const LoadInst *load, const Pointer &p)
    {
        if (p.kind != Pointer::Buffer)
            fail("load through a texture or sampler pointer");
        Type *type = load->getType();
        std::string glsl = glslType(type);
        std::string suffix = std::to_string(p.binding) + "_" + std::to_string(p.offset);
        unsigned width = (unsigned)layout.getTypeStoreSize(type->getScalarType());
        if (type->getScalarType()->isIntegerTy(1))
            fail("boolean load from a buffer");
        unsigned components = 1;
        if (auto *v = dyn_cast<FixedVectorType>(type))
            components = v->getNumElements();
        std::string scalarName = type->getScalarType()->isHalfTy() ? "half" : type->getScalarType()->isFloatTy() ? "float" : "i" + std::to_string(width * 8);
        if (p.vertexIndexed) {
            if (type->getScalarType()->isIntegerTy() && width > 2)
                fail("vertex attribute of " + std::to_string(width * 8) + "-bit integer type");
            if (type->getScalarType()->isHalfTy())
                fail("vertex attribute of half type");
            std::string name = "a" + suffix;
            std::string declaredType = type->getScalarType()->isIntegerTy() ? (components == 1 ? "float" : "vec" + std::to_string(components)) : glsl;
            if (!declared.count(name)) {
                declared.insert(name);
                attributeDecls.push_back("attribute highp " + declaredType + " " + name + ";");
                attributeJson.push_back("{\"name\":\"" + name + "\",\"buffer\":" + std::to_string(p.binding) + ",\"offset\":" + std::to_string(p.offset) +
                                        ",\"stride\":" + std::to_string(p.stride) + ",\"scalar\":\"" + scalarName + "\",\"components\":" + std::to_string(components) + "}");
            }
            if (type->getScalarType()->isIntegerTy())
                return components == 1 ? "int(" + name + " + 0.5)" : "ivec" + std::to_string(components) + "(" + name + " + 0.5)";
            return name;
        }
        std::string name = "u" + suffix + (p.instanceIndexed ? "i" : "");
        if (!declared.count(name)) {
            declared.insert(name);
            uniformDecls.push_back("uniform highp " + glsl + " " + name + ";");
            uniformJson.push_back("{\"name\":\"" + name + "\",\"buffer\":" + std::to_string(p.binding) + ",\"offset\":" + std::to_string(p.offset) + ",\"instanceStride\":" +
                                  std::to_string(p.instanceIndexed ? p.stride : 0) + ",\"scalar\":\"" + scalarName + "\",\"components\":" + std::to_string(components) + "}");
        }
        return name;
    }

    std::string vectorCompare(CmpInst::Predicate pred, const std::string &a, const std::string &b, bool vector)
    {
        std::string op;
        std::string fn;
        switch (pred) {
        case CmpInst::FCMP_OEQ: case CmpInst::FCMP_UEQ: case CmpInst::ICMP_EQ: op = "=="; fn = "equal"; break;
        case CmpInst::FCMP_ONE: case CmpInst::FCMP_UNE: case CmpInst::ICMP_NE: op = "!="; fn = "notEqual"; break;
        case CmpInst::FCMP_OLT: case CmpInst::FCMP_ULT: case CmpInst::ICMP_SLT: case CmpInst::ICMP_ULT: op = "<"; fn = "lessThan"; break;
        case CmpInst::FCMP_OLE: case CmpInst::FCMP_ULE: case CmpInst::ICMP_SLE: case CmpInst::ICMP_ULE: op = "<="; fn = "lessThanEqual"; break;
        case CmpInst::FCMP_OGT: case CmpInst::FCMP_UGT: case CmpInst::ICMP_SGT: case CmpInst::ICMP_UGT: op = ">"; fn = "greaterThan"; break;
        case CmpInst::FCMP_OGE: case CmpInst::FCMP_UGE: case CmpInst::ICMP_SGE: case CmpInst::ICMP_UGE: op = ">="; fn = "greaterThanEqual"; break;
        default: fail("comparison predicate is not supported");
        }
        return vector ? fn + "(" + a + ", " + b + ")" : a + " " + op + " " + b;
    }

    std::string component(const std::string &v, unsigned i, unsigned width)
    {
        static const char *names = "xyzw";
        return width == 1 ? v : v + "." + names[i];
    }

    unsigned width(Type *t)
    {
        return isa<FixedVectorType>(t) ? cast<FixedVectorType>(t)->getNumElements() : 1;
    }

    static bool constantOf(const Value *pointer, int &index, std::string &name)
    {
        auto *g = dyn_cast<GlobalVariable>(pointer);
        if (!g || g->getSection() != "air.fc_initializer")
            return false;
        std::string n = g->getName().str();
        size_t tag = n.find(".MTL_FC_INIT_");
        if (n.rfind("_Z", 0) != 0 || tag == std::string::npos)
            fail("function constant with an unknown name " + n);
        size_t at = 2;
        size_t length = 0;
        while (at < n.size() && isdigit((unsigned char)n[at]))
            length = length * 10 + (n[at++] - '0');
        name = n.substr(at, length);
        index = atoi(n.c_str() + tag + 13);
        return true;
    }

    std::string constantMacro(const Value *pointer, const char *suffix)
    {
        int index;
        std::string name;
        if (!constantOf(pointer, index, name))
            fail("a function constant that is not a global of the library");
        std::string macro = "charon_fc" + std::to_string(index) + suffix;
        if (!declared.count(macro)) {
            declared.insert(macro);
            if (!*suffix) {
                auto *g = cast<GlobalVariable>(pointer);
                Type *t = g->getValueType();
                if (t->isVectorTy() || t->isStructTy() || t->isArrayTy())
                    fail("a function constant of a vector or aggregate type");
                std::string type = t->isIntegerTy(8) || t->isIntegerTy(1) ? "bool" : t->isIntegerTy() ? "int" : "float";
                constantJson.push_back("{\"index\":" + std::to_string(index) + ",\"name\":\"" + name + "\",\"type\":\"" + type + "\"}");
            }
        }
        return macro;
    }

    std::string sizeUniform(int binding)
    {
        std::string uniform = "tsize" + std::to_string(binding);
        if (!declared.count(uniform)) {
            declared.insert(uniform);
            uniformDecls.push_back("uniform highp vec2 " + uniform + ";");
            sizeJson.push_back("{\"name\":\"" + uniform + "\",\"texture\":" + std::to_string(binding) + "}");
        }
        return uniform;
    }

    void read(const CallInst *ci)
    {
        if (vertex)
            fail("reading a texture in a vertex function, which the SGX 543 has no texture units for");
        auto tp = pointers.find(ci->getArgOperand(0));
        if (tp == pointers.end() || tp->second.kind != Pointer::Texture)
            fail("reading a texture that is not an argument");
        if (cast<StructType>(ci->getType())->getElementType(0)->getScalarType()->isIntegerTy())
            fail("reading a texture of integers");
        for (unsigned k : {3u, 4u, 5u}) {
            auto *c = dyn_cast<Constant>(ci->getArgOperand(k));
            if (!c || !c->isNullValue())
                fail("reading a texture with an offset, a level or an array slice");
        }
        std::string size = sizeUniform(tp->second.binding);
        std::string coord = "(vec2(" + get(ci->getArgOperand(2)).text + ") + vec2(0.5)) / " + size;
        Value_ r;
        r.aggregate = true;
        r.fields = {temp(cast<StructType>(ci->getType())->getElementType(0), "texture2D(" + textureNames[tp->second.binding] + ", " + coord + ")"), "1"};
        values[ci] = r;
    }

    std::string call(const CallInst *ci)
    {
        Function *callee = ci->getCalledFunction();
        if (!callee)
            fail("indirect call");
        std::string name = callee->getName().str();
        auto arg = [&](unsigned i) { return text(ci->getArgOperand(i)); };
        auto has = [&](const char *prefix) { return name.rfind(prefix, 0) == 0; };
        Type *rt = ci->getType();
        std::string type = rt->isVoidTy() || rt->isStructTy() ? "" : glslType(rt);
        if (has("air.sample_depth_2d.") || has("air.sample_compare_depth_2d.")) {
            bool compare = has("air.sample_compare_depth_2d.");
            if (vertex)
                fail("sampling a texture in a vertex function, which the SGX 543 has no texture units for");
            auto tp = pointers.find(ci->getArgOperand(0));
            if (tp == pointers.end() || tp->second.kind != Pointer::Texture)
                fail("sampling a depth texture that is not an argument");
            unsigned c = compare ? 5 : 4;
            auto *normalised = dyn_cast<ConstantInt>(ci->getArgOperand(c));
            auto *offset = dyn_cast<Constant>(ci->getArgOperand(c + 1));
            auto *control = dyn_cast<ConstantInt>(ci->getArgOperand(c + 2));
            auto *clamp = dyn_cast<Constant>(ci->getArgOperand(c + 4));
            if (!normalised || normalised->isZero())
                fail("sampling a depth texture in pixel coordinates");
            if (!offset || !offset->isNullValue())
                fail("sampling a depth texture with an offset");
            if (!control || !control->isZero())
                fail("sampling a depth texture with a level of detail or gradients");
            if (!clamp || !clamp->isNullValue())
                fail("sampling a depth texture with a minimum level of detail clamp");
            std::string t = textureNames[tp->second.binding];
            if (compare) {
                auto sampler = pointers.find(ci->getArgOperand(1));
                if (sampler == pointers.end() || sampler->second.kind != Pointer::Sampler)
                    fail("comparing a depth texture with a sampler that is constant in the library");
                if (!depthBindings.count(tp->second.binding))
                    fail("comparing a texture that is not a depth texture");
                compareBindings.insert(tp->second.binding);
                return "shadow2DEXT(" + t + ", vec3(" + arg(3) + ", " + arg(4) + "))";
            }
            return "texture2D(" + t + ", " + arg(3) + ").r";
        }
        if (has("air.sample_texture_2d.")) {
            if (vertex)
                fail("sampling a texture in a vertex function, which the SGX 543 has no texture units for");
            auto tp = pointers.find(ci->getArgOperand(0));
            if (tp == pointers.end() || tp->second.kind != Pointer::Texture)
                fail("sampling a texture that is not an argument");
            {
                Type *result = ci->getType()->isStructTy() ? cast<StructType>(ci->getType())->getElementType(0) : ci->getType();
                if (result->getScalarType()->isIntegerTy())
                    fail("sampling a texture of integers");
            }
            if (isa<ConstantInt>(ci->getArgOperand(3)) && cast<ConstantInt>(ci->getArgOperand(3))->isZero())
                fail("sampling with pixel coordinates");
            const Value *offset = ci->getArgOperand(4);
            if (!(isa<Constant>(offset) && cast<Constant>(offset)->isNullValue()))
                fail("sampling with a non-zero offset");
            auto *flag = dyn_cast<ConstantInt>(ci->getArgOperand(5));
            if (!flag)
                fail("sample control that is not constant");
            if (ci->arg_size() == 9) {
                auto *clamp = dyn_cast<Constant>(ci->getArgOperand(7));
                if (!clamp || !clamp->isNullValue())
                    fail("sampling with a minimum level of detail clamp");
            }
            std::string sampled;
            std::string t = textureNames[tp->second.binding];
            if (flag->isZero()) {
                sampled = "texture2D(" + t + ", " + arg(2) + ")";
            } else {
                auto *kind = dyn_cast<ConstantInt>(ci->getArgOperand(ci->arg_size() - 1));
                if (!kind)
                    fail("sample control kind that is not constant");
                if (kind->getZExtValue() == 0)
                    sampled = "texture2D(" + t + ", " + arg(2) + ", " + arg(6) + ")";
                else if (kind->getZExtValue() == 1)
                    fail("sampling with an explicit level of detail");
                else
                    fail("sampling with gradients");
            }
            return sampled;
        }
        if (name == "air.is_function_constant_defined")
            return "(" + constantMacro(ci->getArgOperand(0), "_defined") + " != 0)";
        if (has("air.normalize_function_constant_predicate."))
            return "(" + arg(0) + " != 0 ? 1 : 0)";
        if (has("air.dfdx.") || has("air.dfdy.") || has("air.fwidth.")) {
            usesDerivatives = true;
            const char *fn = has("air.dfdx.") ? "dFdx" : has("air.dfdy.") ? "dFdy" : "fwidth";
            return std::string(fn) + "(" + arg(0) + ")";
        }
        if (has("air.get_width_texture_2d") || has("air.get_height_texture_2d")) {
            auto tp = pointers.find(ci->getArgOperand(0));
            if (tp == pointers.end() || tp->second.kind != Pointer::Texture)
                fail("texture size of a value that is not a texture argument");
            std::string uniform = sizeUniform(tp->second.binding);
            return std::string("int(") + uniform + (has("air.get_width_texture_2d") ? ".x)" : ".y)");
        }
        if (has("air.convert.")) {
            std::string a = arg(0);
            return type + "(" + a + ")";
        }
        struct Simple { const char *air; const char *glsl; };
        static const Simple simple[] = {
            {"fabs", "abs"}, {"fmax", "max"}, {"fmin", "min"}, {"max", "max"}, {"min", "min"}, {"pow", "pow"}, {"sin", "sin"}, {"cos", "cos"},
            {"tan", "tan"}, {"asin", "asin"}, {"acos", "acos"}, {"atan", "atan"}, {"sqrt", "sqrt"}, {"rsqrt", "inversesqrt"}, {"exp", "exp"},
            {"exp2", "exp2"}, {"log", "log"}, {"log2", "log2"}, {"floor", "floor"}, {"ceil", "ceil"}, {"fract", "fract"}, {"dot", "dot"},
            {"length", "length"}, {"normalize", "normalize"}, {"distance", "distance"}, {"cross", "cross"}, {"mix", "mix"}, {"step", "step"},
            {"smoothstep", "smoothstep"}, {"sign", "sign"}, {"clamp", "clamp"}, {"saturate", "clamp01"}, {"fmuladd", "fma"}, {"fma", "fma"},
            {"atan2", "atan"}, {"reflect", "reflect"}, {"trunc", "trunc"}, {"round", "round"}, {"rint", "round"}};
        std::string base = name;
        for (const char *prefix : {"air.fast_", "air.precise_", "air.", "llvm."}) {
            if (has(prefix)) {
                base = name.substr(strlen(prefix));
                break;
            }
        }
        size_t dot = base.find('.');
        if (dot != std::string::npos)
            base = base.substr(0, dot);
        for (auto &entry : simple) {
            if (base != entry.air)
                continue;
            std::string fn = entry.glsl;
            std::vector<std::string> a;
            for (unsigned i = 0; i < ci->arg_size(); i++)
                if (!ci->getArgOperand(i)->getType()->isIntegerTy(1) || i + 1 < ci->arg_size())
                    a.push_back(arg(i));
            if (fn == "clamp01")
                return "clamp(" + a[0] + ", 0.0, 1.0)";
            if (fn == "fma")
                return "(" + a[0] + " * " + a[1] + " + " + a[2] + ")";
            if (fn == "trunc")
                return "(sign(" + a[0] + ") * floor(abs(" + a[0] + ")))";
            if (fn == "round")
                return "floor(" + a[0] + " + 0.5)";
            if (rt->getScalarType()->isIntegerTy())
                fail("an integer " + base);
            std::string s = fn + "(";
            for (size_t i = 0; i < a.size(); i++)
                s += (i ? ", " : "") + a[i];
            return s + ")";
        }
        fail("call to " + name + " has no GLSL ES 1.00 form");
    }

    void instruction(const Instruction &i)
    {
        switch (i.getOpcode()) {
        case Instruction::FAdd: case Instruction::FSub: case Instruction::FMul: case Instruction::FDiv:
        case Instruction::Add: case Instruction::Sub: case Instruction::Mul: case Instruction::SDiv: {
            static const std::map<unsigned, const char *> ops = {{Instruction::FAdd, "+"}, {Instruction::FSub, "-"}, {Instruction::FMul, "*"}, {Instruction::FDiv, "/"},
                                                                  {Instruction::Add, "+"}, {Instruction::Sub, "-"}, {Instruction::Mul, "*"}, {Instruction::SDiv, "/"}};
            if (i.getType()->getScalarType()->isIntegerTy() && i.getType()->getScalarType()->getIntegerBitWidth() < 32)
                fail("narrow integer arithmetic");
            define(&i, text(i.getOperand(0)) + " " + ops.at(i.getOpcode()) + " " + text(i.getOperand(1)));
            return;
        }
        case Instruction::FRem: {
            std::string a = text(i.getOperand(0)), b = text(i.getOperand(1));
            std::string q = "(" + a + " / " + b + ")";
            define(&i, a + " - " + b + " * (sign" + q + " * floor(abs" + q + "))");
            return;
        }
        case Instruction::FNeg:
            define(&i, "-" + text(i.getOperand(0)));
            return;
        case Instruction::And: case Instruction::Or: case Instruction::Xor: {
            Type *t = i.getType();
            if (t->getScalarType()->isIntegerTy(1)) {
                if (isa<VectorType>(t))
                    fail("vector boolean logic");
                const char *op = i.getOpcode() == Instruction::And ? "&&" : i.getOpcode() == Instruction::Or ? "||" : "!=";
                define(&i, text(i.getOperand(0)) + " " + op + " " + text(i.getOperand(1)));
                return;
            }
            if (i.getOpcode() == Instruction::And && !isa<VectorType>(t))
                if (auto *c = dyn_cast<ConstantInt>(i.getOperand(1))) {
                    uint64_t m = c->getZExtValue() + 1;
                    if (m && (m & (m - 1)) == 0) {
                        define(&i, "int(mod(float" + text(i.getOperand(0)) + ", " + number((double)m) + "))");
                        return;
                    }
                }
            fail("integer bitwise operation");
        }
        case Instruction::Shl: case Instruction::LShr: {
            auto *c = dyn_cast<ConstantInt>(i.getOperand(1));
            if (!c || isa<VectorType>(i.getType()))
                fail("shift by a non-constant amount");
            double k = std::ldexp(1.0, (int)c->getZExtValue());
            if (i.getOpcode() == Instruction::Shl)
                define(&i, text(i.getOperand(0)) + " * " + std::to_string((long long)k));
            else
                define(&i, "int(floor(float" + text(i.getOperand(0)) + " / " + number(k) + "))");
            return;
        }
        case Instruction::FPExt: case Instruction::FPTrunc:
            define(&i, get(i.getOperand(0)).text);
            return;
        case Instruction::SIToFP: case Instruction::UIToFP: case Instruction::FPToSI: case Instruction::FPToUI:
            define(&i, glslType(i.getType()) + "(" + get(i.getOperand(0)).text + ")");
            return;
        case Instruction::ZExt: case Instruction::SExt: {
            Type *from = i.getOperand(0)->getType();
            if (isa<VectorType>(from))
                fail("vector extension");
            if (from->isIntegerTy(1))
                define(&i, text(i.getOperand(0)) + " ? 1 : 0");
            else {
                if (vertexIds.count(i.getOperand(0)))
                    vertexIds.insert(&i);
                if (instanceIds.count(i.getOperand(0)))
                    instanceIds.insert(&i);
                define(&i, get(i.getOperand(0)).text);
            }
            return;
        }
        case Instruction::Trunc: {
            Type *to = i.getType();
            if (isa<VectorType>(to))
                fail("vector truncation");
            if (to->isIntegerTy(1))
                define(&i, "mod(float" + text(i.getOperand(0)) + ", 2.0) != 0.0");
            else
                define(&i, get(i.getOperand(0)).text);
            return;
        }
        case Instruction::ICmp: case Instruction::FCmp: {
            auto *c = cast<CmpInst>(&i);
            bool vec = isa<VectorType>(i.getOperand(0)->getType());
            define(&i, vectorCompare(c->getPredicate(), text(i.getOperand(0)), text(i.getOperand(1)), vec));
            return;
        }
        case Instruction::Select: {
            std::string cond = text(i.getOperand(0)), a = text(i.getOperand(1)), b = text(i.getOperand(2));
            if (isa<VectorType>(i.getOperand(0)->getType())) {
                unsigned n = width(i.getType());
                std::string s = glslType(i.getType()) + "(";
                for (unsigned k = 0; k < n; k++)
                    s += (k ? ", " : "") + component(cond, k, n) + " ? " + component(a, k, n) + " : " + component(b, k, n);
                define(&i, s + ")");
            } else {
                define(&i, cond + " ? " + a + " : " + b);
            }
            return;
        }
        case Instruction::ExtractElement: {
            auto *c = dyn_cast<ConstantInt>(i.getOperand(1));
            if (!c)
                fail("extract with a dynamic index");
            Value_ r;
            r.text = components(i.getOperand(0)).at((size_t)c->getZExtValue());
            values[&i] = r;
            return;
        }
        case Instruction::InsertElement: {
            auto *c = dyn_cast<ConstantInt>(i.getOperand(2));
            if (!c)
                fail("insert with a dynamic index");
            std::vector<std::string> comps = components(i.getOperand(0));
            comps.at((size_t)c->getZExtValue()) = get(i.getOperand(1)).text;
            values[&i] = composed(i.getType(), comps);
            return;
        }
        case Instruction::ShuffleVector: {
            auto *sv = cast<ShuffleVectorInst>(&i);
            unsigned n = width(i.getOperand(0)->getType());
            std::vector<std::string> a = components(i.getOperand(0)), b = components(i.getOperand(1));
            unsigned outWidth = width(i.getType());
            if (outWidth == 1)
                fail("shuffle producing a scalar");
            std::vector<std::string> comps;
            std::string zero = constant(Constant::getNullValue(cast<FixedVectorType>(i.getType())->getElementType()));
            for (unsigned k = 0; k < outWidth; k++) {
                int m = sv->getMaskValue(k);
                comps.push_back(m < 0 ? zero : (unsigned)m < n ? a[m] : b[m - n]);
            }
            values[&i] = composed(i.getType(), comps);
            return;
        }
        case Instruction::InsertValue: {
            auto *iv = cast<InsertValueInst>(&i);
            Value_ base;
            if (isa<UndefValue>(iv->getAggregateOperand()) || isa<PoisonValue>(iv->getAggregateOperand())) {
                base.aggregate = true;
                auto *st = cast<StructType>(iv->getType());
                base.fields.assign(st->getNumElements(), "");
            } else {
                base = get(iv->getAggregateOperand());
            }
            if (iv->getNumIndices() != 1)
                fail("nested aggregate");
            base.fields[iv->getIndices()[0]] = get(iv->getInsertedValueOperand()).text;
            values[&i] = base;
            return;
        }
        case Instruction::ExtractValue: {
            auto *ev = cast<ExtractValueInst>(&i);
            Value_ &agg = get(ev->getAggregateOperand());
            if (!agg.aggregate || ev->getNumIndices() != 1)
                fail("extractvalue from a non-aggregate");
            Value_ r;
            r.text = agg.fields[ev->getIndices()[0]];
            values[&i] = r;
            return;
        }
        case Instruction::GetElementPtr:
            pointers[&i] = offsetPointer(cast<GetElementPtrInst>(&i));
            return;
        case Instruction::Load: {
            auto *load = cast<LoadInst>(&i);
            {
                int index;
                std::string name;
                if (constantOf(load->getPointerOperand(), index, name)) {
                    define(&i, constantMacro(load->getPointerOperand(), ""));
                    return;
                }
                if (auto *g = dyn_cast<GlobalVariable>(load->getPointerOperand())) {
                    auto found = globals.find(g);
                    if (found == globals.end())
                        fail("a load from a global that nothing stores to");
                    define(&i, found->second);
                    return;
                }
            }
            auto it = pointers.find(load->getPointerOperand());
            if (it == pointers.end())
                fail("load from memory that is not a buffer argument");
            define(&i, bufferLoad(load, it->second));
            return;
        }
        case Instruction::Call: {
            auto *ci = cast<CallInst>(&i);
            if (ci->getCalledFunction() && ci->getCalledFunction()->isIntrinsic()) {
                Intrinsic::ID id = ci->getCalledFunction()->getIntrinsicID();
                if (id == Intrinsic::lifetime_start || id == Intrinsic::lifetime_end || id == Intrinsic::assume)
                    return;
            }
            if (ci->getCalledFunction() && ci->getCalledFunction()->getName() == "air.discard_fragment") {
                if (vertex)
                    fail("discard in a vertex function");
                body.push_back(indent + "discard;");
                return;
            }
            if (ci->getCalledFunction() && ci->getCalledFunction()->getName().starts_with("air.get_read_sampler")) {
                Pointer sampler;
                sampler.kind = Pointer::Sampler;
                pointers[ci] = sampler;
                Value_ r;
                r.text = "0";
                values[ci] = r;
                return;
            }
            if (ci->getCalledFunction() && ci->getCalledFunction()->getName().starts_with("air.read_texture_2d.")) {
                read(ci);
                return;
            }
            if (ci->getType()->isStructTy() && ci->getCalledFunction() && (ci->getCalledFunction()->getName().starts_with("air.sample_texture_2d.") ||
                                                                            ci->getCalledFunction()->getName().starts_with("air.sample_depth_2d.") ||
                                                                            ci->getCalledFunction()->getName().starts_with("air.sample_compare_depth_2d."))) {
                Value_ r;
                r.aggregate = true;
                r.fields = {temp(cast<StructType>(ci->getType())->getElementType(0), call(ci)), "1"};
                values[ci] = r;
                return;
            }
            define(&i, call(ci));
            return;
        }
        case Instruction::Store: {
            auto *store = cast<StoreInst>(&i);
            auto *g = dyn_cast<GlobalVariable>(store->getPointerOperand());
            if (!g || g->getSection() == "air.fc_initializer")
                fail("a store that is not to a global of the library");
            auto found = globals.find(g);
            if (found == globals.end()) {
                std::string name = "g" + std::to_string(globals.size());
                declarations.push_back("    " + qualified(store->getValueOperand()->getType()) + " " + name + ";");
                found = globals.emplace(g, name).first;
            }
            body.push_back(indent + found->second + " = " + get(store->getValueOperand()).text + ";");
            return;
        }
        case Instruction::Ret:
            finish(cast<ReturnInst>(&i));
            return;
        case Instruction::PHI:
            return;
        case Instruction::UncondBr: case Instruction::CondBr: case Instruction::Switch:
            branch(i);
            return;
        case Instruction::Unreachable:
            return;
        default:
            fail(std::string("instruction ") + i.getOpcodeName());
        }
    }

    std::vector<std::string> edge(const BasicBlock *from, const BasicBlock *to)
    {
        std::vector<std::string> lines;
        auto inside = loopOf.find(from);
        if (inside != loopOf.end()) {
            Loop &loop = loops[inside->second];
            if (to == loop.header) {
                for (auto &phi : to->phis())
                    lines.push_back(loop.next.at(&phi) + " = " + get(phi.getIncomingValueForBlock(from)).text + ";");
                lines.push_back(loop.cont + " = true;");
                return lines;
            }
            auto target = loopOf.find(to);
            if (target == loopOf.end() || target->second != inside->second)
                lines.push_back(loop.brk + " = true;");
        }
        lines.push_back(reach.at(to) + " = true;");
        for (auto &phi : to->phis())
            lines.push_back(get(&phi).text + " = " + get(phi.getIncomingValueForBlock(from)).text + ";");
        return lines;
    }

    void branch(const Instruction &t)
    {
        const BasicBlock *from = t.getParent();
        auto emit = [&](const std::vector<std::string> &lines) {
            for (auto &l : lines)
                body.push_back(indent + "    " + l);
        };
        if (t.getNumSuccessors() == 1) {
            for (auto &l : edge(from, t.getSuccessor(0)))
                body.push_back(indent + l);
            return;
        }
        if (auto *sw = dyn_cast<SwitchInst>(&t)) {
            if (isa<VectorType>(sw->getCondition()->getType()))
                fail("switch on a vector");
            std::string value = text(sw->getCondition());
            bool first = true;
            for (auto &c : sw->cases()) {
                body.push_back(indent + (first ? "if (" : "} else if (") + value + " == " + std::to_string(c.getCaseValue()->getSExtValue()) + ") {");
                first = false;
                emit(edge(from, c.getCaseSuccessor()));
            }
            if (first) {
                for (auto &l : edge(from, sw->getDefaultDest()))
                    body.push_back(indent + l);
                return;
            }
            body.push_back(indent + "} else {");
            emit(edge(from, sw->getDefaultDest()));
            body.push_back(indent + "}");
            return;
        }
        body.push_back(indent + "if (" + get(cast<CondBrInst>(&t)->getCondition()).text + ") {");
        emit(edge(from, t.getSuccessor(0)));
        body.push_back(indent + "} else {");
        emit(edge(from, t.getSuccessor(1)));
        body.push_back(indent + "}");
    }

    void structure()
    {
        ReversePostOrderTraversal<Function *> order(&function);
        std::vector<BasicBlock *> blocks(order.begin(), order.end());
        std::map<const BasicBlock *, unsigned> position;
        for (unsigned n = 0; n < blocks.size(); n++)
            position[blocks[n]] = n;
        std::map<const BasicBlock *, std::vector<const BasicBlock *>> latches;
        for (BasicBlock *b : blocks)
            for (unsigned k = 0; k < b->getTerminator()->getNumSuccessors(); k++) {
                BasicBlock *to = b->getTerminator()->getSuccessor(k);
                if (position.at(to) <= position.at(b))
                    latches[to].push_back(b);
            }
        for (auto &entry : latches) {
            Loop loop;
            loop.header = entry.first;
            loop.blocks.insert(entry.first);
            std::vector<const BasicBlock *> work(entry.second.begin(), entry.second.end());
            while (!work.empty()) {
                const BasicBlock *b = work.back();
                work.pop_back();
                if (!loop.blocks.insert(b).second)
                    continue;
                for (const BasicBlock *pred : predecessors(b))
                    work.push_back(pred);
            }
            for (const BasicBlock *b : loop.blocks)
                if (loopOf.count(b))
                    fail("a loop inside a loop");
            for (const BasicBlock *b : loop.blocks)
                loopOf[b] = (unsigned)loops.size();
            std::string id = std::to_string(loops.size());
            loop.brk = "brk" + id;
            loop.cont = "cont" + id;
            loop.index = "it" + id;
            loops.push_back(loop);
        }
        hoist = blocks.size() > 1;
        if (hoist) {
            for (BasicBlock *b : blocks) {
                if (b != &function.getEntryBlock()) {
                    std::string name = "r" + std::to_string(position.at(b));
                    reach[b] = name;
                    declarations.push_back("    bool " + name + " = false;");
                }
                for (auto &phi : b->phis()) {
                    std::string name = fresh();
                    declarations.push_back("    " + qualified(phi.getType()) + " " + name + ";");
                    Value_ r;
                    r.text = name;
                    values[&phi] = r;
                    auto in = loopOf.find(b);
                    if (in != loopOf.end() && loops[in->second].header == b) {
                        std::string next = fresh();
                        declarations.push_back("    " + qualified(phi.getType()) + " " + next + ";");
                        loops[in->second].next[&phi] = next;
                    }
                }
            }
            for (auto &loop : loops) {
                declarations.push_back("    bool " + loop.brk + " = false;");
                declarations.push_back("    bool " + loop.cont + " = false;");
            }
        }
        std::set<const BasicBlock *> done;
        for (BasicBlock *b : blocks) {
            if (done.count(b))
                continue;
            auto in = loopOf.find(b);
            if (in == loopOf.end()) {
                block(b);
                done.insert(b);
                continue;
            }
            Loop &loop = loops[in->second];
            body.push_back("    for (int " + loop.index + " = 0; " + loop.index + " < " + std::to_string(LoopLimit) + "; " + loop.index + "++) {");
            std::string outer = indent;
            for (BasicBlock *l : blocks) {
                if (!loop.blocks.count(l))
                    continue;
                if (l != loop.header)
                    body.push_back("        " + reach.at(l) + " = false;");
            }
            for (BasicBlock *l : blocks) {
                if (!loop.blocks.count(l))
                    continue;
                block(l, "    ");
                done.insert(l);
            }
            body.push_back("        if (" + loop.brk + " || !" + loop.cont + ")");
            body.push_back("            break;");
            for (auto &phi : loop.header->phis())
                body.push_back("        " + values.at(&phi).text + " = " + loop.next.at(&phi) + ";");
            body.push_back("        " + loop.cont + " = false;");
            body.push_back("    }");
            indent = outer;
        }
    }

    void block(BasicBlock *b, const std::string &extra = "")
    {
        bool guarded = hoist && b != &function.getEntryBlock();
        std::string outer = indent;
        indent = extra + indent;
        if (guarded) {
            body.push_back(indent + "if (" + reach.at(b) + ") {");
            indent += "    ";
        }
        for (auto &i : *b)
            instruction(i);
        if (guarded) {
            indent = indent.substr(0, indent.size() - 4);
            body.push_back(indent + "}");
        }
        indent = outer;
    }

    void finish(const ReturnInst *ret)
    {
        Value_ &r = get(ret->getReturnValue());
        std::vector<std::string> fields = r.aggregate ? r.fields : std::vector<std::string>{r.text};
        for (size_t k = 0; k < fields.size(); k++)
            if (fields[k].empty()) {
                Type *t = r.aggregate ? cast<StructType>(ret->getReturnValue()->getType())->getElementType((unsigned)k) : ret->getReturnValue()->getType();
                fields[k] = constant(Constant::getNullValue(t));
            }
        if (vertex) {
            for (size_t k = 0; k < fields.size() && k < outputs.size(); k++) {
                const ArgInfo &o = outputs[k];
                if (o.kind == "air.position") {
                    body.push_back(indent + "gl_Position = " + fields[k] + ";");
                    body.push_back(indent + "gl_Position.y *= charon_flip;");
                    body.push_back(indent + "gl_Position.z = gl_Position.z * 2.0 - gl_Position.w;");
                } else if (o.kind == "air.point_size") {
                    body.push_back(indent + "gl_PointSize = " + fields[k] + ";");
                } else if (o.kind == "air.vertex_output") {
                    std::string name = varyingName(o, (unsigned)k);
                    Type *t = r.aggregate ? cast<StructType>(ret->getReturnValue()->getType())->getElementType((unsigned)k) : ret->getReturnValue()->getType();
                    std::string declaredType = t->isIntegerTy() ? "float" : glslType(t);
                    if (!declared.count(name)) {
                        declared.insert(name);
                        samplerDecls.push_back("varying " + std::string(halfLike(t) ? "mediump " : "highp ") + declaredType + " " + name + ";");
                        varyingJson.push_back("{\"name\":\"" + name + "\",\"argument\":" + std::to_string(k) + ",\"flat\":false}");
                    }
                    std::string value = t->isIntegerTy(1) ? "(" + fields[k] + " ? 1.0 : 0.0)" : t->isIntegerTy() ? "float(" + fields[k] + ")" : fields[k];
                    body.push_back(indent + "" + name + " = " + value + ";");
                } else {
                    fail("vertex output " + o.kind + " is not supported");
                }
            }
        } else {
            std::map<int, std::string> colours;
            for (size_t k = 0; k < outputs.size(); k++) {
                if (outputs[k].kind != "air.render_target")
                    fail("fragment output " + outputs[k].kind + " is not supported");
                if (outputs[k].location < 0 || outputs[k].location > 3 || colours.count(outputs[k].location))
                    fail("fragment outputs to render targets that are not among the first four");
                Type *t = r.aggregate ? cast<StructType>(ret->getReturnValue()->getType())->getElementType((unsigned)k) : ret->getReturnValue()->getType();
                if (t->getScalarType()->isIntegerTy())
                    fail("fragment output of an integer type");
                unsigned n = width(t);
                std::string colour = fields[k];
                if (n == 1)
                    colour = "vec4(" + fields[k] + ", 0.0, 0.0, 1.0)";
                else if (n == 2)
                    colour = "vec4(" + fields[k] + ", 0.0, 1.0)";
                else if (n == 3)
                    colour = "vec4(" + fields[k] + ", 1.0)";
                colours[outputs[k].location] = colour;
            }
            bool any = !colours.empty();
            if (colours.size() > 1) {
                usesOutput = true;
                auto last = colours.rbegin();
                std::string chain = last->second;
                for (++last; last != colours.rend(); ++last)
                    chain = "(charon_output == " + std::to_string(last->first) + " ? " + last->second + " : " + chain + ")";
                body.push_back(indent + "gl_FragColor = " + chain + ";");
            } else if (any) {
                body.push_back(indent + "gl_FragColor = " + colours.begin()->second + ";");
            }
            if (!any)
                fail("fragment shader with no colour output");
        }
    }

    std::string run()
    {
        setup();
        for (auto &f : module) {
            if (f.getSection() != "air.static_init")
                continue;
            if (f.size() != 1)
                fail("static initialisation with control flow");
            for (auto &i : f.getEntryBlock())
                if (!isa<ReturnInst>(i))
                    instruction(i);
        }
        structure();
        for (auto &line : body) {
            if (line.find("charon_flip") != std::string::npos && !vertex)
                usesFlip = true;
            if (line.find("charon_target") != std::string::npos)
                usesTarget = true;
        }
        std::ostringstream out;
        out << "#version 100\n";
        if (usesDerivatives)
            out << "#extension GL_OES_standard_derivatives : enable\n";
        if (!compareBindings.empty())
            out << "#extension GL_EXT_shadow_samplers : require\n";
        for (auto &line : body)
            if (line.find("gl_LastFragData") != std::string::npos) {
                out << "#extension GL_EXT_shader_framebuffer_fetch : require\n";
                break;
            }
        if (!vertex) {
            out << "#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\n";
            out << "precision highp int;\n";
        }
        if (vertex || usesFlip)
            out << "uniform highp float charon_flip;\n";
        if (usesTarget)
            out << "uniform highp vec2 charon_target;\n";
        if (usesOutput)
            out << "uniform highp int charon_output;\n";
        if (usesInstanceId)
            out << "uniform highp float charon_instance;\n";
        if (vertex && usesVertexId)
            out << "attribute highp float a_vertex_id;\n";
        for (auto &d : attributeDecls)
            out << d << "\n";
        for (auto &d : uniformDecls)
            out << d << "\n";
        for (int j : fetches)
            out << "uniform sampler2D charon_attachment" << j << ";\n";
        for (auto &t : textureNames) {
            out << "uniform " << (compareBindings.count(t.first) ? "sampler2DShadow " : "sampler2D ") << t.second << ";\n";
            textureJson.push_back("{\"name\":\"" + t.second + "\",\"index\":" + std::to_string(t.first) + ",\"depth\":" + (depthBindings.count(t.first) ? "true" : "false") +
                                  ",\"compare\":" + (compareBindings.count(t.first) ? "true" : "false") + "}");
        }
        for (auto &d : samplerDecls)
            out << d << "\n";
        out << "void main()\n{\n";
        for (auto &l : declarations)
            out << l << "\n";
        for (auto &l : body)
            out << l << "\n";
        out << "}\n";
        return out.str();
    }

    std::string outputList() const
    {
        std::set<int> locations;
        if (!vertex)
            for (auto &o : outputs)
                if (o.kind == "air.render_target")
                    locations.insert(o.location);
        std::string s = "[";
        for (int l : locations)
            s += (s.size() > 1 ? "," : "") + std::to_string(l);
        return s + "]";
    }

    std::string fetchList() const
    {
        std::string s = "[";
        for (int j : fetches)
            s += (s.size() > 1 ? "," : "") + std::string("{\"attachment\":") + std::to_string(j) + ",\"name\":\"charon_attachment" + std::to_string(j) + "\"}";
        return s + "]";
    }

    std::string json()
    {
        auto join = [](const std::vector<std::string> &v) {
            std::string s = "[";
            for (size_t i = 0; i < v.size(); i++)
                s += (i ? "," : "") + v[i];
            return s + "]";
        };
        return "{\"stage\":\"" + std::string(vertex ? "vertex" : "fragment") + "\",\"entry\":\"" + function.getName().str() + "\",\"usesVertexId\":" +
               (usesVertexId ? "true" : "false") + ",\"attributes\":" + join(attributeJson) + ",\"uniforms\":" + join(uniformJson) + ",\"textures\":" + join(textureJson) +
               ",\"varyings\":" + join(varyingJson) + ",\"constants\":" + join(constantJson) + ",\"inputs\":" + join(inputJson) + ",\"sizes\":" + join(sizeJson) + ",\"outputs\":" + outputList() + ",\"fetches\":" + fetchList() + ",\"usesInstanceId\":" + (usesInstanceId ? "true" : "false") + "}\n";
    }
};

}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: air2es MODULE.bc OUTPUT-PREFIX\n");
        return 2;
    }
    LLVMContext context;
    auto buffer = MemoryBuffer::getFile(argv[1]);
    if (!buffer) {
        fprintf(stderr, "%s: cannot read\n", argv[1]);
        return 2;
    }
    auto module = parseBitcodeFile((*buffer)->getMemBufferRef(), context);
    if (!module) {
        fprintf(stderr, "%s: not readable bitcode\n", argv[1]);
        return 2;
    }
    Module &m = **module;
    bool vertex = m.getNamedMetadata("air.vertex") != nullptr;
    bool fragment = m.getNamedMetadata("air.fragment") != nullptr;
    if (!vertex && !fragment) {
        printf("%s: SKIP not a vertex or fragment function%s\n", argv[1], m.getNamedMetadata("air.kernel") ? " (compute kernel)" : "");
        return 3;
    }
    NamedMDNode *entries = m.getNamedMetadata(vertex ? "air.vertex" : "air.fragment");
    Function *entry = mdconst::dyn_extract<Function>(entries->getOperand(0)->getOperand(0));
    try {
        Translator t(m, *entry, vertex);
        std::string glsl = t.run();
        std::string prefix = argv[2];
        FILE *f = fopen((prefix + (vertex ? ".vert" : ".frag")).c_str(), "w");
        fputs(glsl.c_str(), f);
        fclose(f);
        f = fopen((prefix + ".json").c_str(), "w");
        fputs(t.json().c_str(), f);
        fclose(f);
        printf("%s: OK %s %s\n", argv[1], vertex ? "vertex" : "fragment", entry->getName().str().c_str());
    } catch (Failure &failure) {
        printf("%s: FAIL %s %s: %s\n", argv[1], vertex ? "vertex" : "fragment", entry->getName().str().c_str(), failure.message.c_str());
        return 1;
    }
    return 0;
}
