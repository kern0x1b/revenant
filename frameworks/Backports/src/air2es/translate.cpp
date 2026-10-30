#include "translate.h"

#include <cmath>
#include <cstdio>
#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace air2es {

namespace {

using TagMap = std::map<std::string, std::vector<Metadata *>>;

using BlockSets = std::map<BasicBlock *, std::set<BasicBlock *>>;

TagMap parseTags(const MDNode *node, unsigned first)
{
    TagMap tags;
    std::string key;
    for (unsigned i = first; i < node->getNumOperands(); i++) {
        Metadata *operand = node->getOperand(i);
        const MDString *text = dyn_cast_or_null<MDString>(operand);
        if (text && text->getString().starts_with("air.")) {
            key = text->getString().str();
            tags[key];
        } else if (!key.empty()) {
            tags[key].push_back(operand);
        }
    }
    return tags;
}

bool tagString(const TagMap &tags, const std::string &key, std::string &value)
{
    auto found = tags.find(key);
    if (found == tags.end())
        return false;
    for (Metadata *item : found->second)
        if (auto *text = dyn_cast_or_null<MDString>(item)) {
            value = text->getString().str();
            return true;
        }
    return false;
}

bool tagInteger(const TagMap &tags, const std::string &key, uint64_t &value)
{
    auto found = tags.find(key);
    if (found == tags.end() || found->second.empty())
        return false;
    auto *constant = mdconst::dyn_extract_or_null<ConstantInt>(found->second[0]);
    if (!constant)
        return false;
    value = constant->getZExtValue();
    return true;
}

struct Member {
    std::string name;
    uint64_t offset;
    uint64_t size;
    std::string type;
};

struct Binding {
    std::string kind;
    std::string name;
    uint64_t index = 0;
    uint64_t stride = 0;
    bool indexedByVertex = false;
    std::vector<Member> members;
    Argument *argument = nullptr;
};

struct Address {
    Binding *binding = nullptr;
    uint64_t offset = 0;
    bool indexed = false;
};

struct Local {
    std::string name;
    Type *type = nullptr;
};

struct Output {
    std::string kind;
    std::string name;
    uint64_t index = 0;
};

const char *const kArgumentKinds[] = {"air.buffer", "air.texture", "air.sampler", "air.vertex_id",
                                      "air.position", "air.fragment_input", "air.thread_position_in_grid"};

const char *const kLanes[] = {"x", "y", "z", "w"};

struct PlainFunction {
    const char *air;
    const char *glsl;
    unsigned arguments;
};

const PlainFunction kPlainFunctions[] = {
    {"air.fast_sin.f32", "sin", 1},
    {"air.fast_cos.f32", "cos", 1},
    {"air.fast_fabs.f32", "abs", 1},
    {"air.fast_fabs.v2f32", "abs", 1},
    {"air.fast_fabs.v3f32", "abs", 1},
    {"air.fast_floor.v2f32", "floor", 1},
    {"air.fast_fract.f32", "fract", 1},
    {"air.fast_fract.v3f32", "fract", 1},
    {"air.fast_rsqrt.f32", "inversesqrt", 1},
    {"air.fast_sqrt.f32", "sqrt", 1},
    {"air.fast_fmax.f32", "max", 2},
    {"air.fast_fmax.v2f32", "max", 2},
    {"air.fast_fmin.f32", "min", 2},
    {"air.fast_pow.f32", "pow", 2},
    {"air.dot.v2f32", "dot", 2},
    {"air.dot.v3f32", "dot", 2},
    {"air.fast_clamp.f32", "clamp", 3},
    {"air.fast_clamp.v3f32", "clamp", 3},
    {"air.mix.f32", "mix", 3},
    {"air.mix.v3f32", "mix", 3},
};

const PlainFunction *plainFunction(const std::string &name)
{
    for (const PlainFunction &function : kPlainFunctions)
        if (name == function.air)
            return &function;
    return nullptr;
}

bool paddedVectorOf(Type *narrow, Type *wide)
{
    auto *from = dyn_cast<FixedVectorType>(narrow);
    auto *to = dyn_cast<FixedVectorType>(wide);
    return from && to && from->getNumElements() == 3 && to->getNumElements() == 4 &&
           from->getElementType() == to->getElementType();
}

bool scalarOf(const std::string &typeName, std::string &scalar, unsigned &components)
{
    std::string base = typeName.compare(0, 7, "packed_") == 0 ? typeName.substr(7) : typeName;
    static const char *const table[][2] = {{"float", "float"}, {"half", "half"}, {"int", "i32"},
                                           {"uint", "i32"}, {"bool", "i8"}};
    for (const auto &entry : table) {
        std::string prefix = entry[0];
        if (base.compare(0, prefix.size(), prefix) != 0)
            continue;
        std::string rest = base.substr(prefix.size());
        if (rest.empty())
            components = 1;
        else if (rest.size() == 1 && rest[0] >= '2' && rest[0] <= '4')
            components = (unsigned)(rest[0] - '0');
        else
            return false;
        scalar = entry[1];
        return true;
    }
    return false;
}

unsigned scalarBytes(const std::string &scalar)
{
    if (scalar == "float" || scalar == "i32")
        return 4;
    if (scalar == "half" || scalar == "i16")
        return 2;
    return 1;
}

std::string glslType(Type *type)
{
    if (type->isIntegerTy(1))
        return "bool";
    if (type->isIntegerTy())
        return "int";
    if (type->isFloatTy() || type->isHalfTy())
        return "float";
    if (auto *vector = dyn_cast<FixedVectorType>(type)) {
        unsigned count = vector->getNumElements();
        if (count < 2 || count > 4)
            return "";
        Type *element = vector->getElementType();
        if (element->isIntegerTy(1))
            return "bvec" + std::to_string(count);
        if (element->isIntegerTy())
            return "ivec" + std::to_string(count);
        if (element->isFloatTy() || element->isHalfTy())
            return "vec" + std::to_string(count);
    }
    return "";
}

std::string floatLiteral(double value)
{
    char text[64];
    snprintf(text, sizeof(text), "%.9g", value);
    std::string out = text;
    if (out.find_first_of(".eE") == std::string::npos)
        out += ".0";
    return value < 0 ? "(" + out + ")" : out;
}

std::string join(const std::vector<std::string> &items, const char *separator = ", ")
{
    std::string out;
    for (const std::string &item : items)
        out += (out.empty() ? "" : separator) + item;
    return out;
}

class Shader {
public:
    Shader(Function &function, Stage stage, const DataLayout &layout, std::string &refusal)
        : function_(function), stage_(stage), layout_(layout), refusal_(refusal) {}

    bool readInterface(const MDNode *entry)
    {
        if (auto *outputs = dyn_cast_or_null<MDNode>(entry->getOperand(1)))
            for (const MDOperand &operand : outputs->operands()) {
                auto *node = dyn_cast_or_null<MDNode>(operand.get());
                auto *kind = node && node->getNumOperands() ? dyn_cast_or_null<MDString>(node->getOperand(0)) : nullptr;
                if (!kind)
                    return refuse("an output this emitter does not read");
                Output output;
                output.kind = kind->getString().str();
                TagMap tags = parseTags(node, 0);
                tagString(tags, "air.arg_name", output.name);
                tagInteger(tags, output.kind, output.index);
                outputs_.push_back(output);
            }
        auto *arguments = dyn_cast_or_null<MDNode>(entry->getOperand(2));
        if (!arguments)
            return refuse("a function with no argument metadata");
        for (const MDOperand &operand : arguments->operands()) {
            auto *node = dyn_cast_or_null<MDNode>(operand.get());
            if (!node || node->getNumOperands() < 2)
                return refuse("an argument with no metadata");
            auto *number = mdconst::dyn_extract_or_null<ConstantInt>(node->getOperand(0));
            if (!number)
                return refuse("an argument without its position");
            TagMap tags = parseTags(node, 1);
            if (tags.count("air.threadgroup"))
                return refuse("threadgroup memory, which one fragment pass cannot hold; it needs a multi-pass design");
            Binding binding;
            for (const char *kind : kArgumentKinds)
                if (tags.count(kind)) {
                    binding.kind = kind;
                    break;
                }
            if (binding.kind.empty())
                return refuse("an argument of a kind this emitter does not read");
            if (binding.kind == "air.texture" && tags.count("air.write"))
                binding.kind = "air.write_texture";
            tagString(tags, "air.arg_name", binding.name);
            tagInteger(tags, "air.location_index", binding.index);
            tagInteger(tags, "air.arg_type_size", binding.stride);
            std::string typeName;
            tagString(tags, "air.arg_type_name", typeName);
            if (binding.kind == "air.texture" && typeName.compare(0, 11, "texturecube") == 0)
                binding.kind = "air.texture_cube";
            auto info = tags.find("air.struct_type_info");
            if (info != tags.end() && !info->second.empty()) {
                auto *fields = dyn_cast_or_null<MDNode>(info->second[0]);
                if (!fields || !readMembers(fields, binding.members))
                    return refuse("a struct member this emitter does not read in " + binding.name);
            }
            if (binding.kind == "air.buffer" && binding.members.empty()) {
                std::string scalar;
                unsigned components = 0;
                uint64_t size = binding.stride;
                if (scalarOf(typeName, scalar, components))
                    size = components * scalarBytes(scalar);
                binding.members.push_back(Member{binding.name, 0, size, typeName});
            }
            bindings_.push_back(binding);
            argumentNumbers_.push_back((unsigned)number->getZExtValue());
        }
        return true;
    }

    bool translate(std::string &source, std::string &reflection)
    {
        for (Argument &argument : function_.args()) {
            size_t slot = 0;
            while (slot < bindings_.size() && argumentNumbers_[slot] != argument.getArgNo())
                slot++;
            if (slot == bindings_.size())
                return refuse("an argument with no metadata: " + std::to_string(argument.getArgNo()));
            bindings_[slot].argument = &argument;
            argumentSlot_[&argument] = slot;
        }
        for (BasicBlock &block : function_)
            for (Instruction &instruction : block)
                if (auto *gep = dyn_cast<GetElementPtrInst>(&instruction))
                    if (!gep->hasAllConstantIndices()) {
                        Address address;
                        if (resolve(gep, address) && address.indexed)
                            address.binding->indexedByVertex = true;
                    }
        for (size_t slot = 0; slot < bindings_.size(); slot++) {
            const Binding &binding = bindings_[slot];
            if (stage_ == Stage::Kernel && (binding.kind == "air.vertex_id" || binding.kind == "air.position" ||
                                            binding.kind == "air.fragment_input"))
                return refuse(binding.kind + " in a kernel, which has no vertex or fragment input");
            if ((binding.kind == "air.write_texture" || binding.kind == "air.thread_position_in_grid") &&
                stage_ != Stage::Kernel)
                return refuse(binding.kind + " outside a kernel");
            if (binding.kind == "air.vertex_id" && stage_ != Stage::Vertex)
                return refuse("a vertex id in a fragment function");
            if (binding.kind == "air.position" && stage_ != Stage::Fragment)
                return refuse("a position argument in a vertex function");
            if (binding.kind == "air.fragment_input" && stage_ != Stage::Fragment)
                return refuse("a fragment input in a vertex function");
        }
        for (size_t slot = 0; slot < bindings_.size(); slot++)
            if (bindings_[slot].kind == "air.position" && !bindings_[slot].argument->use_empty()) {
                if (!declareLocal("vec4 position;\n", "position"))
                    return false;
                statement("position = gl_FragCoord;\n");
                needFlip();
                needTarget();
                statement("position.y = revenant_flip > 0.0 ? revenant_target.y - gl_FragCoord.y : gl_FragCoord.y;\n");
                break;
            }
        for (size_t slot = 0; slot < bindings_.size(); slot++)
            if (bindings_[slot].kind == "air.thread_position_in_grid" && !bindings_[slot].argument->use_empty()) {
                if (!declareLocal("ivec2 gid;\n", "gid"))
                    return false;
                statement("gid = ivec2(floor(gl_FragCoord.xy));\n");
                break;
            }
        if (stage_ == Stage::Kernel && !declareLocal("bool revenant_written = false;\n", "revenant_written"))
            return false;
        if (!region(&function_.getEntryBlock(), nullptr))
            return false;
        if (!returned_)
            return refuse("a function that never returns");
        if (stage_ == Stage::Kernel) {
            if (output_.empty())
                return refuse("a kernel that writes no texture");
            statement("if (!revenant_written) discard;\n");
        }
        std::string body;
        for (const std::string &line : locals_)
            body += "    " + line;
        for (const std::string &line : statements_)
            body += line;
        source = "#version 100\n";
        if (stage_ != Stage::Vertex)
            source += "precision mediump float;\n";
        source += join(declarations_, "") + "void main() {\n" + body + "}\n";
        reflection = this->reflection();
        return true;
    }

private:
    bool refuse(const std::string &reason)
    {
        if (refusal_.empty())
            refusal_ = reason;
        return false;
    }

    bool readMembers(const MDNode *fields, std::vector<Member> &members)
    {
        for (unsigned i = 0; i + 4 < fields->getNumOperands(); i += 5) {
            auto *offset = mdconst::dyn_extract_or_null<ConstantInt>(fields->getOperand(i));
            auto *size = mdconst::dyn_extract_or_null<ConstantInt>(fields->getOperand(i + 1));
            auto *type = dyn_cast_or_null<MDString>(fields->getOperand(i + 3));
            auto *name = dyn_cast_or_null<MDString>(fields->getOperand(i + 4));
            if (!offset || !size || !type || !name || name->getString().empty())
                return false;
            members.push_back(Member{name->getString().str(), offset->getZExtValue(), size->getZExtValue(), type->getString().str()});
        }
        return !members.empty();
    }

    Binding *bindingOf(const Value *value)
    {
        while (auto *cast = dyn_cast<BitCastInst>(value))
            value = cast->getOperand(0);
        auto inlined = inlineBindings_.find(value);
        if (inlined != inlineBindings_.end())
            return inlined->second;
        auto found = argumentSlot_.find(value);
        return found == argumentSlot_.end() ? nullptr : &bindings_[found->second];
    }

    const Local *localOf(const Value *pointer)
    {
        while (auto *cast = dyn_cast<BitCastInst>(pointer))
            pointer = cast->getOperand(0);
        auto inlined = inlineLocals_.find(pointer);
        if (inlined != inlineLocals_.end())
            return inlined->second;
        auto found = localPointers_.find(pointer);
        return found == localPointers_.end() ? nullptr : &found->second;
    }

    uint64_t allocSize(Type *type)
    {
        return layout_.getTypeAllocSize(type).getFixedValue();
    }

    bool isVertexIndex(const Value *index)
    {
        const Value *source = index;
        if (auto *extend = dyn_cast<ZExtInst>(index))
            source = extend->getOperand(0);
        else if (auto *extend = dyn_cast<SExtInst>(index))
            source = extend->getOperand(0);
        const Binding *binding = bindingOf(source);
        return binding && binding->kind == "air.vertex_id";
    }

    bool resolve(const Value *pointer, Address &out)
    {
        while (auto *cast = dyn_cast<BitCastInst>(pointer))
            pointer = cast->getOperand(0);
        if (const auto *argument = dyn_cast<Argument>(pointer)) {
            Binding *binding = bindingOf(argument);
            if (!binding || binding->kind != "air.buffer")
                return false;
            out.binding = binding;
            return true;
        }
        const auto *gep = dyn_cast<GetElementPtrInst>(pointer);
        if (!gep || !resolve(gep->getPointerOperand(), out) || out.indexed)
            return false;
        Type *type = gep->getSourceElementType();
        for (unsigned i = 0; i < gep->getNumIndices(); i++) {
            const Value *index = gep->getOperand(i + 1);
            if (i == 0 && !isa<ConstantInt>(index)) {
                if (!isVertexIndex(index) || allocSize(type) != out.binding->stride)
                    return false;
                out.indexed = true;
                continue;
            }
            auto *constant = dyn_cast<ConstantInt>(index);
            if (!constant)
                return false;
            uint64_t element = constant->getZExtValue();
            if (i == 0) {
                out.offset += element * allocSize(type);
            } else if (auto *structure = dyn_cast<StructType>(type)) {
                if (element >= structure->getNumElements())
                    return false;
                out.offset += layout_.getStructLayout(structure)->getElementOffset((unsigned)element).getFixedValue();
                type = structure->getElementType((unsigned)element);
            } else if (auto *array = dyn_cast<ArrayType>(type)) {
                out.offset += element * allocSize(array->getElementType());
                type = array->getElementType();
            } else {
                return false;
            }
        }
        return true;
    }

    const Member *memberAt(const Binding &binding, uint64_t offset)
    {
        for (const Member &member : binding.members)
            if (offset >= member.offset && offset < member.offset + member.size)
                return &member;
        return nullptr;
    }

    void declare(const std::string &line, const std::string &name)
    {
        if (declared_.count(name))
            return;
        declared_.insert(name);
        declarations_.push_back(line);
    }

    bool declareLocal(const std::string &line, const std::string &name)
    {
        if (declared_.count(name))
            return refuse("a name used twice: " + name);
        declared_.insert(name);
        locals_.push_back(line);
        return true;
    }

    void needFlip()
    {
        declare("uniform float revenant_flip;\n", "revenant_flip");
    }

    void needTarget()
    {
        declare("uniform vec2 revenant_target;\n", "revenant_target");
    }

    bool accessMember(Binding &binding, const Member &field, uint64_t offset, Type *loaded, std::string &out)
    {
        std::string scalar;
        unsigned components = 0;
        if (!scalarOf(field.type, scalar, components))
            return refuse("a member of type " + field.type + " in " + binding.name);
        unsigned width = scalarBytes(scalar);
        if (components * width != field.size)
            return refuse("a member whose size does not match its type in " + binding.name);
        bool attribute = binding.indexedByVertex;
        if (attribute && scalar != "float" && scalar != "i8")
            return refuse("a vertex attribute of scalar " + scalar + " in " + binding.name +
                          ", which the loader reads as a short");
        bool real = attribute || scalar == "float" || scalar == "half";
        std::string suffix = std::to_string(components);
        std::string glsl = real ? (components == 1 ? "float" : "vec" + suffix) : (components == 1 ? "int" : "ivec" + suffix);
        std::string name = attribute ? "a_" + field.name : field.name;
        bool fresh = !declared_.count(name);
        declare((attribute ? "attribute " : "uniform ") + glsl + " " + name + ";\n", name);
        if (fresh) {
            std::string common = "\"name\": " + jsonQuote(name) + ", \"buffer\": " + std::to_string(binding.index) +
                                 ", \"offset\": " + std::to_string(field.offset);
            std::string tail = ", \"scalar\": " + jsonQuote(scalar) + ", \"components\": " + std::to_string(components) + "}";
            if (attribute)
                attributeLines_.push_back("{" + common + ", \"stride\": " + std::to_string(binding.stride) + tail);
            else
                uniformLines_.push_back("{" + common + ", \"instanceStride\": 0" + tail);
        }
        uint64_t within = offset - field.offset;
        if (components == 1) {
            if (within != 0)
                return refuse("a part of a scalar member in " + binding.name);
            out = name;
            return true;
        }
        if (!loaded->isVectorTy()) {
            if (within % width != 0 || within / width >= components)
                return refuse("a load of " + name + " that this emitter does not map to a component");
            out = name + "." + kLanes[within / width];
            return true;
        }
        unsigned count = cast<FixedVectorType>(loaded)->getNumElements();
        bool packedFloat3 = within == 0 && components == 3 && count == 4 && scalar == "float";
        if (packedFloat3 && !memberAt(binding, field.offset + field.size)) {
            out = glslType(loaded) + "(" + name + ", 0.0)";
            return true;
        }
        if (within % width != 0 || within / width + count > components)
            return refuse("a vector load of " + name + " that this emitter does not map to lanes");
        unsigned first = (unsigned)(within / width);
        if (first == 0 && count == components) {
            out = name;
            return true;
        }
        std::string list;
        for (unsigned lane = 0; lane < count; lane++)
            list += (lane ? ", " : "") + name + "." + kLanes[first + lane];
        out = glslType(loaded) + "(" + list + ")";
        return true;
    }

    bool tableLoad(const GetElementPtrInst *gep, Type *loaded, std::string &out)
    {
        auto *table = cast<GlobalVariable>(gep->getPointerOperand());
        const Constant *initializer = table->hasInitializer() ? table->getInitializer() : nullptr;
        auto *array = initializer ? dyn_cast<ArrayType>(initializer->getType()) : nullptr;
        auto *first = dyn_cast<ConstantInt>(gep->getOperand(1));
        if (!array || gep->getNumIndices() != 2 || !first || !first->isZero() || array->getElementType() != loaded)
            return refuse("a load from a constant table this emitter does not map");
        uint64_t count = array->getNumElements();
        std::vector<std::string> elements;
        for (uint64_t i = 0; i < count; i++) {
            std::string text;
            if (!expression(initializer->getAggregateElement(i), text))
                return false;
            elements.push_back(text);
        }
        Value *index = gep->getOperand(2);
        if (auto *constant = dyn_cast<ConstantInt>(index)) {
            if (constant->getZExtValue() >= count)
                return refuse("a constant table read past its end");
            out = elements[constant->getZExtValue()];
            return true;
        }
        if (count == 0)
            return refuse("a variable read from an empty constant table");
        std::string selector;
        if (!expression(index, selector))
            return false;
        out = elements[count - 1];
        for (uint64_t i = count - 1; i-- > 0;)
            out = "((" + selector + " == " + std::to_string(i) + ") ? " + elements[i] + " : " + out + ")";
        return true;
    }

    bool loadExpression(LoadInst *load, std::string &out)
    {
        if (auto *gep = dyn_cast<GetElementPtrInst>(load->getPointerOperand()); gep && isa<GlobalVariable>(gep->getPointerOperand()))
            return tableLoad(gep, load->getType(), out);
        if (const Local *slot = localOf(load->getPointerOperand())) {
            bool padded = paddedVectorOf(slot->type, load->getType());
            if (slot->type != load->getType() && !padded)
                return refuse("a load of a local at another type");
            std::string temp;
            if (!local(*load, temp))
                return false;
            statement(temp + " = " + (padded ? glslType(load->getType()) + "(" + slot->name + ", 0.0)" : slot->name) + ";\n");
            out = temp;
            return true;
        }
        Address address;
        if (!resolve(load->getPointerOperand(), address) || !address.binding)
            return refuse("a load from an address this emitter does not read");
        if (address.binding->kind != "air.buffer")
            return refuse("a load from " + address.binding->kind);
        if (address.indexed != address.binding->indexedByVertex)
            return refuse("a buffer read both per vertex and at a fixed place: " + address.binding->name);
        const Member *field = memberAt(*address.binding, address.offset);
        if (!field)
            return refuse("a load outside the members of " + address.binding->name);
        return accessMember(*address.binding, *field, address.offset, load->getType(), out);
    }

    bool expression(Value *value, std::string &out)
    {
        Type *type = value->getType();
        if (auto *extend = dyn_cast<ZExtInst>(value); extend && isVertexIndex(extend))
            return expression(extend->getOperand(0), out);
        if (auto *instruction = dyn_cast<Instruction>(value)) {
            auto found = names_.find(instruction);
            if (found == names_.end())
                return refuse("a value used before it is defined");
            out = found->second;
            return true;
        }
        if (auto *argument = dyn_cast<Argument>(value)) {
            auto inlined = inlineValues_.find(argument);
            if (inlined != inlineValues_.end()) {
                out = inlined->second;
                return true;
            }
            Binding *binding = bindingOf(argument);
            if (!binding)
                return refuse("an argument with no metadata");
            if (binding->kind == "air.vertex_id") {
                declare("attribute float a_vertex_id;\n", "a_vertex_id");
                out = "int(a_vertex_id)";
                return true;
            }
            if (binding->kind == "air.position") {
                out = "position";
                return true;
            }
            if (binding->kind == "air.thread_position_in_grid") {
                out = "gid";
                return true;
            }
            if (binding->kind == "air.fragment_input") {
                std::string type = glslType(argument->getType());
                if (type.empty())
                    return refuse("a fragment input of a type this emitter does not hold");
                declare("varying " + type + " " + binding->name + ";\n", binding->name);
                out = binding->name;
                return true;
            }
            return refuse("an argument of kind " + binding->kind + " used as a value");
        }
        if (auto *constant = dyn_cast<ConstantFP>(value)) {
            double number = constant->getValueAPF().convertToDouble();
            if (!std::isfinite(number))
                return refuse("a non-finite constant");
            out = floatLiteral(number);
            if (type->isVectorTy()) {
                std::string glsl = glslType(type);
                if (glsl.empty())
                    return refuse("a splat constant of a type this emitter does not hold");
                out = glsl + "(" + out + ")";
            }
            return true;
        }
        if (auto *constant = dyn_cast<ConstantInt>(value)) {
            if (constant->getType()->isIntegerTy(1)) {
                out = constant->isOne() ? "true" : "false";
                return true;
            }
            int64_t number = constant->getSExtValue();
            out = number < 0 ? "(" + std::to_string(number) + ")" : std::to_string(number);
            return true;
        }
        if (isa<UndefValue>(value) || isa<ConstantAggregateZero>(value)) {
            std::string glsl = glslType(type);
            if (glsl.empty())
                return refuse("a zero of a type this emitter does not hold");
            std::string zero = type->isIntegerTy(1) ? "false" : type->isIntegerTy() ? "0" : "0.0";
            out = type->isVectorTy() ? glsl + "(" + zero + ")" : zero;
            return true;
        }
        if (auto *vector = dyn_cast<Constant>(value); vector && type->isVectorTy()) {
            std::string glsl = glslType(type);
            if (glsl.empty())
                return refuse("a vector constant of a type this emitter does not hold");
            unsigned count = cast<FixedVectorType>(type)->getNumElements();
            std::string list;
            for (unsigned i = 0; i < count; i++) {
                std::string element;
                Constant *lane = vector->getAggregateElement(i);
                if (!lane || !expression(lane, element))
                    return false;
                list += (i ? ", " : "") + element;
            }
            out = glsl + "(" + list + ")";
            return true;
        }
        return refuse("a value this emitter does not translate");
    }

    struct Loop {
        PHINode *index = nullptr;
        Instruction *next = nullptr;
        Instruction *test = nullptr;
        BasicBlock *exit = nullptr;
        int64_t first = 0;
        int64_t last = 0;
    };

    struct Frame {
        const Function *function = nullptr;
        std::string result;
        bool returned = false;
    };

    void statement(const std::string &text)
    {
        statements_.push_back(std::string(4 * (depth_ + 1), ' ') + text);
    }

    BlockSets postDominators(Function &function)
    {
        BlockSets sets;
        std::set<BasicBlock *> all;
        for (BasicBlock &block : function)
            all.insert(&block);
        for (BasicBlock &block : function)
            sets[&block] = all;
        bool changed = true;
        while (changed) {
            changed = false;
            for (BasicBlock &block : function) {
                Instruction *terminator = block.getTerminator();
                std::set<BasicBlock *> meet;
                for (unsigned i = 0; i < terminator->getNumSuccessors(); i++) {
                    const std::set<BasicBlock *> next = sets[terminator->getSuccessor(i)];
                    if (i == 0) {
                        meet = next;
                        continue;
                    }
                    std::set<BasicBlock *> common;
                    for (BasicBlock *candidate : meet)
                        if (next.count(candidate))
                            common.insert(candidate);
                    meet = common;
                }
                meet.insert(&block);
                if (meet != sets[&block]) {
                    sets[&block] = meet;
                    changed = true;
                }
            }
        }
        return sets;
    }

    BasicBlock *postDominator(BasicBlock *block)
    {
        Function *function = block->getParent();
        if (!postDominators_.count(function))
            postDominators_[function] = postDominators(*function);
        const BlockSets &sets = postDominators_[function];
        BasicBlock *best = nullptr;
        for (BasicBlock *candidate : sets.at(block))
            if (candidate != block && (!best || sets.at(candidate).size() > sets.at(best).size()))
                best = candidate;
        return best;
    }

    bool loopOf(BasicBlock *header, Loop &loop)
    {
        auto *branch = dyn_cast<BranchInst>(header->getTerminator());
        if (!branch || !branch->isConditional())
            return false;
        bool staysFirst = branch->getSuccessor(0) == header;
        bool staysSecond = branch->getSuccessor(1) == header;
        if (staysFirst == staysSecond)
            return false;
        bool exitOnTrue = !staysFirst;
        loop.exit = branch->getSuccessor(staysFirst ? 1 : 0);
        auto *test = dyn_cast<ICmpInst>(branch->getCondition());
        if (!test || test->getPredicate() != (exitOnTrue ? ICmpInst::ICMP_EQ : ICmpInst::ICMP_NE))
            return false;
        auto *bound = dyn_cast<ConstantInt>(test->getOperand(1));
        auto *next = dyn_cast<BinaryOperator>(test->getOperand(0));
        if (!bound || !next || next->getParent() != header || next->getOpcode() != Instruction::Add)
            return false;
        auto *step = dyn_cast<ConstantInt>(next->getOperand(1));
        auto *index = dyn_cast<PHINode>(next->getOperand(0));
        if (!step || !step->isOne() || !index || index->getParent() != header || index->getNumIncomingValues() != 2)
            return false;
        if (index->getIncomingValueForBlock(header) != next)
            return false;
        BasicBlock *before = nullptr;
        Value *start = nullptr;
        for (unsigned i = 0; i < 2; i++)
            if (index->getIncomingBlock(i) != header) {
                before = index->getIncomingBlock(i);
                start = index->getIncomingValue(i);
            }
        auto *first = dyn_cast_or_null<ConstantInt>(start);
        if (!before || !first || first->getSExtValue() >= bound->getSExtValue())
            return false;
        for (User *user : next->users())
            if (user != index && user != test)
                return false;
        for (User *user : test->users())
            if (user != branch)
                return false;
        for (User *user : index->users()) {
            auto *inside = dyn_cast<Instruction>(user);
            if (!inside || inside->getParent() != header)
                return false;
        }
        if (isa<PHINode>(loop.exit->front()))
            return false;
        loop.index = index;
        loop.next = next;
        loop.test = test;
        loop.first = first->getSExtValue();
        loop.last = bound->getSExtValue();
        return true;
    }

    bool emitLoop(BasicBlock *header, const Loop &loop)
    {
        std::string index = "t" + std::to_string(counter_++);
        names_[loop.index] = index;
        statement("for (int " + index + " = " + std::to_string(loop.first) + "; " + index + " < " +
                  std::to_string(loop.last) + "; " + index + "++) {\n");
        depth_++;
        for (Instruction &instruction : *header) {
            if (isa<PHINode>(instruction) || instruction.isTerminator() || &instruction == loop.next ||
                &instruction == loop.test)
                continue;
            if (!emit(instruction))
                return false;
        }
        if (!edgeCopies(header, header))
            return false;
        depth_--;
        statement("}\n");
        return true;
    }

    bool edgeCopies(BasicBlock *from, BasicBlock *to)
    {
        Loop loop;
        bool counted = loopOf(to, loop);
        struct Copy {
            PHINode *phi;
            std::string value;
        };
        std::vector<Copy> copies;
        for (Instruction &instruction : *to) {
            auto *phi = dyn_cast<PHINode>(&instruction);
            if (!phi)
                break;
            if (counted && phi == loop.index)
                continue;
            if (!names_.count(phi)) {
                std::string name;
                if (!local(*phi, name))
                    return false;
            }
            if (phi->getBasicBlockIndex(from) < 0)
                return refuse("a phi that has no value for one of its edges");
            std::string value;
            if (!expression(phi->getIncomingValueForBlock(from), value))
                return false;
            copies.push_back(Copy{phi, value});
        }
        if (copies.size() == 1) {
            statement(names_[copies[0].phi] + " = " + copies[0].value + ";\n");
            return true;
        }
        std::vector<std::string> temps;
        for (const Copy &copy : copies) {
            std::string temp = "t" + std::to_string(counter_++);
            locals_.push_back(glslType(copy.phi->getType()) + " " + temp + ";\n");
            statement(temp + " = " + copy.value + ";\n");
            temps.push_back(temp);
        }
        for (size_t i = 0; i < copies.size(); i++)
            statement(names_[copies[i].phi] + " = " + temps[i] + ";\n");
        return true;
    }

    bool side(BasicBlock *from, BasicBlock *to, BasicBlock *join)
    {
        return edgeCopies(from, to) && region(to, join);
    }

    bool finish(ReturnInst &ret)
    {
        if (!frames_.empty()) {
            frames_.back().returned = true;
            if (!ret.getReturnValue())
                return true;
            std::string value;
            if (!expression(ret.getReturnValue(), value))
                return false;
            if (!frames_.back().result.empty())
                statement(frames_.back().result + " = " + value + ";\n");
            return true;
        }
        returned_ = true;
        if (stage_ == Stage::Kernel && !ret.getReturnValue())
            return true;
        return emitReturn(ret);
    }

    bool region(BasicBlock *block, BasicBlock *stop)
    {
        while (block && block != stop) {
            if (!visited_.insert(block).second)
                return refuse("control flow that reaches one block twice");
            Loop loop;
            if (loopOf(block, loop)) {
                if (!emitLoop(block, loop))
                    return false;
                block = loop.exit;
                continue;
            }
            for (Instruction &instruction : *block) {
                if (isa<PHINode>(instruction) || instruction.isTerminator())
                    continue;
                if (!emit(instruction))
                    return false;
            }
            Instruction *terminator = block->getTerminator();
            if (auto *ret = dyn_cast<ReturnInst>(terminator))
                return finish(*ret);
            auto *branch = dyn_cast<BranchInst>(terminator);
            if (!branch)
                return refuse("a terminator this emitter does not structure");
            if (branch->isUnconditional()) {
                if (!edgeCopies(block, branch->getSuccessor(0)))
                    return false;
                block = branch->getSuccessor(0);
                continue;
            }
            BasicBlock *join = postDominator(block);
            if (!join)
                return refuse("a branch that never rejoins");
            std::string condition;
            if (!expression(branch->getCondition(), condition))
                return false;
            statement("if (" + condition + ") {\n");
            depth_++;
            if (!side(block, branch->getSuccessor(0), join))
                return false;
            depth_--;
            statement("} else {\n");
            depth_++;
            if (!side(block, branch->getSuccessor(1), join))
                return false;
            depth_--;
            statement("}\n");
            block = join;
        }
        return true;
    }

    bool inlineCall(CallInst &call, Function &callee)
    {
        for (const Frame &frame : frames_)
            if (frame.function == &callee)
                return refuse("a recursive call to " + callee.getName().str());
        if (call.arg_size() != callee.arg_size())
            return refuse("a call to " + callee.getName().str() + " with an argument count this emitter does not map");
        for (unsigned i = 0; i < call.arg_size(); i++) {
            Value *actual = call.getArgOperand(i);
            Argument *formal = callee.getArg(i);
            if (Binding *binding = bindingOf(actual)) {
                inlineBindings_[formal] = binding;
                continue;
            }
            if (const Local *slot = localOf(actual)) {
                inlineLocals_[formal] = slot;
                continue;
            }
            std::string text;
            if (!expression(actual, text))
                return false;
            inlineValues_[formal] = text;
        }
        Frame frame;
        frame.function = &callee;
        if (!callee.getReturnType()->isVoidTy() && !local(call, frame.result))
            return false;
        frames_.push_back(frame);
        std::set<const BasicBlock *> outer;
        outer.swap(visited_);
        bool emitted = region(&callee.getEntryBlock(), nullptr);
        visited_.swap(outer);
        bool returned = frames_.back().returned;
        frames_.pop_back();
        if (!emitted)
            return false;
        if (!returned)
            return refuse("a call to " + callee.getName().str() + " that never returns");
        return true;
    }

    bool local(Instruction &instruction, std::string &name)
    {
        std::string type = glslType(instruction.getType());
        if (type.empty())
            return refuse("a value of a type this emitter does not hold");
        name = "t" + std::to_string(counter_++);
        locals_.push_back(type + " " + name + ";\n");
        names_[&instruction] = name;
        return true;
    }

    bool emit(Instruction &instruction)
    {
        if (auto *slot = dyn_cast<AllocaInst>(&instruction)) {
            Type *type = slot->getAllocatedType();
            std::string glsl = glslType(type);
            if (glsl.empty() || type->isStructTy() || type->isArrayTy())
                return refuse("a local of a type this emitter does not hold as a variable");
            Local &local = localPointers_[slot];
            local.name = "v" + std::to_string(counter_++);
            local.type = type;
            locals_.push_back(glsl + " " + local.name + ";\n");
            return true;
        }
        if (auto *cast = dyn_cast<BitCastInst>(&instruction); cast && cast->getType()->isPointerTy() && (localOf(cast) || bindingOf(cast)))
            return true;
        if (auto *store = dyn_cast<StoreInst>(&instruction)) {
            const Local *slot = localOf(store->getPointerOperand());
            bool narrowed = slot && paddedVectorOf(slot->type, store->getValueOperand()->getType());
            if (!slot || (slot->type != store->getValueOperand()->getType() && !narrowed))
                return refuse("a store to an address this emitter does not write as a local");
            std::string text;
            if (!expression(store->getValueOperand(), text))
                return false;
            statement(slot->name + " = " + (narrowed ? glslType(slot->type) + "(" + text + ")" : text) + ";\n");
            return true;
        }
        if (auto *gep = dyn_cast<GetElementPtrInst>(&instruction)) {
            if (isa<GlobalVariable>(gep->getPointerOperand()))
                return true;
            Address address;
            if (!resolve(gep, address))
                return refuse("an address this emitter does not read");
            return true;
        }
        if (auto *extend = dyn_cast<ZExtInst>(&instruction); extend && isVertexIndex(extend))
            return true;
        if (auto *insert = dyn_cast<InsertValueInst>(&instruction)) {
            if (insert->getNumIndices() != 1)
                return refuse("a nested insertvalue");
            std::vector<Value *> fields;
            Value *aggregate = insert->getAggregateOperand();
            if (isa<UndefValue>(aggregate))
                fields.assign(insert->getType()->getStructNumElements(), nullptr);
            else if (aggregates_.count(aggregate))
                fields = aggregates_[aggregate];
            else
                return refuse("an aggregate this emitter does not build");
            fields[insert->getIndices()[0]] = insert->getInsertedValueOperand();
            aggregates_[&instruction] = fields;
            return true;
        }
        if (auto *load = dyn_cast<LoadInst>(&instruction)) {
            std::string text;
            if (!loadExpression(load, text))
                return false;
            names_[load] = text;
            return true;
        }
        if (auto *extend = dyn_cast<ZExtInst>(&instruction)) {
            std::string text;
            if (!expression(extend->getOperand(0), text))
                return false;
            if (extend->getOperand(0)->getType()->isIntegerTy(1))
                text = "int(" + text + ")";
            names_[extend] = text;
            return true;
        }
        if (auto *extract = dyn_cast<ExtractElementInst>(&instruction)) {
            auto *lane = dyn_cast<ConstantInt>(extract->getIndexOperand());
            if (!lane || lane->getZExtValue() > 3)
                return refuse("an extractelement at a lane that is not a constant");
            std::string vector;
            if (!expression(extract->getVectorOperand(), vector))
                return false;
            names_[extract] = "(" + vector + ")." + kLanes[lane->getZExtValue()];
            return true;
        }
        if (auto *insert = dyn_cast<InsertElementInst>(&instruction)) {
            auto *lane = dyn_cast<ConstantInt>(insert->getOperand(2));
            if (!lane || lane->getZExtValue() > 3)
                return refuse("an insertelement at a lane that is not a constant");
            std::string base, value;
            if (!expression(insert->getOperand(0), base) || !expression(insert->getOperand(1), value))
                return false;
            std::string name;
            if (!local(instruction, name))
                return false;
            statement(name + " = " + base + ";\n");
            statement(name + "." + kLanes[lane->getZExtValue()] + " = " + value + ";\n");
            return true;
        }
        if (auto *shuffle = dyn_cast<ShuffleVectorInst>(&instruction)) {
            std::string first, second;
            if (!expression(shuffle->getOperand(0), first) || !expression(shuffle->getOperand(1), second))
                return false;
            unsigned firstCount = cast<FixedVectorType>(shuffle->getOperand(0)->getType())->getNumElements();
            std::string list;
            for (int lane : shuffle->getShuffleMask()) {
                std::string element = "0.0";
                if (lane >= 0 && (unsigned)lane < firstCount)
                    element = "(" + first + ")." + kLanes[lane];
                else if (lane >= 0)
                    element = "(" + second + ")." + kLanes[lane - firstCount];
                list += (list.empty() ? "" : ", ") + element;
            }
            std::string name;
            if (!local(instruction, name))
                return false;
            statement(name + " = " + glslType(shuffle->getType()) + "(" + list + ");\n");
            return true;
        }
        if (auto *binary = dyn_cast<BinaryOperator>(&instruction)) {
            const char *op = nullptr;
            switch (binary->getOpcode()) {
            case Instruction::FAdd: case Instruction::Add: op = "+"; break;
            case Instruction::FSub: case Instruction::Sub: op = "-"; break;
            case Instruction::FMul: case Instruction::Mul: op = "*"; break;
            case Instruction::FDiv: op = "/"; break;
            default: return refuse(std::string("a ") + instruction.getOpcodeName() + " this emitter does not map");
            }
            std::string left, right, name;
            if (!expression(binary->getOperand(0), left) || !expression(binary->getOperand(1), right))
                return false;
            if (!local(instruction, name))
                return false;
            statement(name + " = (" + left + " " + op + " " + right + ");\n");
            return true;
        }
        if (auto *compare = dyn_cast<CmpInst>(&instruction)) {
            const char *op = nullptr;
            switch (compare->getPredicate()) {
            case CmpInst::ICMP_EQ: case CmpInst::FCMP_OEQ: op = "=="; break;
            case CmpInst::ICMP_NE: op = "!="; break;
            case CmpInst::FCMP_OLT: op = "<"; break;
            case CmpInst::FCMP_OGT: op = ">"; break;
            case CmpInst::FCMP_OLE: op = "<="; break;
            case CmpInst::FCMP_OGE: op = ">="; break;
            case CmpInst::ICMP_ULT: case CmpInst::ICMP_ULE: case CmpInst::ICMP_UGT: case CmpInst::ICMP_UGE:
                if (!compare->getOperand(0)->getType()->isIntegerTy(32))
                    return refuse("an unsigned comparison of integers other than 32 bits");
                break;
            default: return refuse("a comparison this emitter does not map");
            }
            std::string left, right, name;
            if (!expression(compare->getOperand(0), left) || !expression(compare->getOperand(1), right))
                return false;
            if (!local(instruction, name))
                return false;
            if (op) {
                statement(name + " = (" + left + " " + op + " " + right + ");\n");
                return true;
            }
            auto below = [](const std::string &a, const std::string &b) {
                return "(((" + a + " < 0) != (" + b + " < 0)) ? (" + a + " >= 0) : (" + a + " < " + b + "))";
            };
            std::string text;
            switch (compare->getPredicate()) {
            case CmpInst::ICMP_ULT: text = below(left, right); break;
            case CmpInst::ICMP_UGT: text = below(right, left); break;
            case CmpInst::ICMP_ULE: text = "!" + below(right, left); break;
            default: text = "!" + below(left, right); break;
            }
            statement(name + " = " + text + ";\n");
            return true;
        }
        if (auto *select = dyn_cast<SelectInst>(&instruction)) {
            std::string condition, yes, no, name;
            if (!expression(select->getCondition(), condition) || !expression(select->getTrueValue(), yes) ||
                !expression(select->getFalseValue(), no))
                return false;
            if (!local(instruction, name))
                return false;
            statement(name + " = " + condition + " ? " + yes + " : " + no + ";\n");
            return true;
        }
        if (auto *cast = dyn_cast<CastInst>(&instruction)) {
            switch (cast->getOpcode()) {
            case Instruction::FPExt: case Instruction::FPTrunc: case Instruction::SIToFP:
            case Instruction::UIToFP: case Instruction::FPToSI:
                break;
            default: return refuse("a cast this emitter does not map");
            }
            std::string operand, name;
            if (!expression(cast->getOperand(0), operand))
                return false;
            std::string type = glslType(cast->getType());
            if (type.empty())
                return refuse("a cast to a type this emitter does not hold");
            if (!local(instruction, name))
                return false;
            statement(name + " = " + type + "(" + operand + ");\n");
            return true;
        }
        if (auto *call = dyn_cast<CallInst>(&instruction))
            return emitCall(*call);
        return refuse(std::string("an instruction this emitter does not translate: ") + instruction.getOpcodeName());
    }

    bool writeTexture(CallInst &call)
    {
        if (call.arg_size() != 5)
            return refuse("a write with an argument count this emitter does not map");
        Binding *texture = bindingOf(call.getArgOperand(0));
        if (!texture || texture->kind != "air.write_texture")
            return refuse("a write to something other than the output texture argument");
        if (!output_.empty() && output_ != texture->name)
            return refuse("a kernel that writes more than one texture");
        Binding *coordinate = bindingOf(call.getArgOperand(1));
        if (!coordinate || coordinate->kind != "air.thread_position_in_grid")
            return refuse("a write at a coordinate other than the thread position");
        auto *level = dyn_cast<ConstantInt>(call.getArgOperand(3));
        if (!level || !level->isZero())
            return refuse("a write at a level other than 0");
        std::string value;
        if (!expression(call.getArgOperand(2), value))
            return false;
        output_ = texture->name;
        outputIndex_ = texture->index;
        statement("gl_FragColor = " + value + ";\n");
        statement("revenant_written = true;\n");
        return true;
    }

    bool sampleCube(CallInst &call)
    {
        if (call.arg_size() != 6)
            return refuse("a cube sample with an argument count this emitter does not map");
        Binding *texture = bindingOf(call.getArgOperand(0));
        if (!texture || texture->kind != "air.texture_cube")
            return refuse("a cube sample of something other than a cube texture argument");
        Binding *sampler = bindingOf(call.getArgOperand(1));
        if (!sampler || sampler->kind != "air.sampler")
            return refuse("a sample with a sampler built into the shader, which the library carries no state for");
        auto *flag = dyn_cast<ConstantInt>(call.getArgOperand(3));
        auto *bias = dyn_cast<ConstantFP>(call.getArgOperand(4));
        auto *offset = dyn_cast<ConstantInt>(call.getArgOperand(5));
        if (!flag || !flag->isZero() || !bias || !bias->isZero() || !offset || !offset->isZero())
            return refuse("a cube sample with a flag, bias or offset this emitter does not map");
        std::string coordinates;
        if (!expression(call.getArgOperand(2), coordinates))
            return false;
        declare("uniform samplerCube " + texture->name + ";\n", texture->name);
        if (!textures_.count(texture->name)) {
            textures_.insert(texture->name);
            textureLines_.push_back("{\"name\": " + jsonQuote(texture->name) + ", \"index\": " + std::to_string(texture->index) +
                                    ", \"depth\": false, \"compare\": false, \"cube\": true}");
        }
        std::string name;
        if (!local(call, name))
            return false;
        statement(name + " = textureCube(" + texture->name + ", " + coordinates + ");\n");
        return true;
    }

    bool emitCall(CallInst &call)
    {
        Function *callee = call.getCalledFunction();
        std::string called = callee ? callee->getName().str() : "";
        if (called.rfind("llvm.lifetime.", 0) == 0)
            return true;
        if (callee && !callee->isDeclaration())
            return inlineCall(call, *callee);
        if (called.rfind("air.wg.barrier", 0) == 0)
            return refuse("a threadgroup barrier, which one fragment pass cannot run; it needs a pass boundary");
        if (called.rfind("air.atomic", 0) == 0)
            return refuse("an atomic operation, which one fragment pass cannot run; it needs a multi-pass design");
        if (called == "air.write_texture_2d.v4f32")
            return writeTexture(call);
        if (called == "air.sample_texture_cube.v4f32")
            return sampleCube(call);
        bool sample = called == "air.sample_texture_2d.v4f32" || called == "air.sample_texture_2d.v4f16";
        bool width = called == "air.get_width_texture_2d";
        bool convert = called.rfind("air.convert.", 0) == 0;
        const PlainFunction *plain = plainFunction(called);
        bool fmod = called == "air.fast_fmod.f32" || called == "air.fast_fmod.v2f32";
        if (!sample && !width && !convert && !plain && !fmod)
            return refuse("a call to " + (called.empty() ? std::string("an indirect target") : called));
        std::vector<std::string> args;
        for (unsigned i = 0; i < call.arg_size(); i++) {
            if (width || (sample && i != 2))
                continue;
            std::string text;
            if (!expression(call.getArgOperand(i), text))
                return false;
            args.push_back(text);
        }
        std::string name;
        if (convert) {
            if (args.size() != 1 || !local(call, name))
                return refuse("a conversion with an argument count this emitter does not map");
            statement(name + " = " + glslType(call.getType()) + "(" + args[0] + ");\n");
            return true;
        }
        if (fmod) {
            if (args.size() != 2 || call.getType() != call.getArgOperand(0)->getType())
                return refuse("a call to " + called + " with an argument count this emitter does not map");
            std::string quotient = "t" + std::to_string(counter_++);
            locals_.push_back(glslType(call.getType()) + " " + quotient + ";\n");
            if (!local(call, name))
                return false;
            statement(quotient + " = " + args[0] + " / " + args[1] + ";\n");
            statement(name + " = " + args[0] + " - " + args[1] + " * (sign(" + quotient + ") * floor(abs(" +
                                  quotient + ")));\n");
            return true;
        }
        if (plain) {
            if (args.size() != plain->arguments || !local(call, name))
                return refuse("a call to " + called + " with an argument count this emitter does not map");
            statement(name + " = " + plain->glsl + "(" + join(args) + ");\n");
            return true;
        }
        if (width) {
            if (call.arg_size() != 2)
                return refuse("a width with an argument count this emitter does not map");
            Binding *texture = bindingOf(call.getArgOperand(0));
            if (!texture || texture->kind != "air.texture")
                return refuse("a width of something other than a texture");
            std::string size = texture->name + "_size";
            bool fresh = !declared_.count(size);
            declare("uniform vec2 " + size + ";\n", size);
            if (fresh)
                sizes_.push_back("{\"name\": " + jsonQuote(size) + ", \"texture\": " + std::to_string(texture->index) + "}");
            if (!local(call, name))
                return false;
            statement(name + " = int(" + size + ".x);\n");
            return true;
        }
        if (call.arg_size() != 8)
            return refuse("a sample with an argument count this emitter does not map");
        Binding *texture = bindingOf(call.getArgOperand(0));
        if (!texture || texture->kind != "air.texture")
            return refuse("a sample of something other than a texture argument");
        Binding *sampler = bindingOf(call.getArgOperand(1));
        if (!sampler || sampler->kind != "air.sampler")
            return refuse("a sample with a sampler built into the shader, which the library carries no state for");
        auto *normalized = dyn_cast<ConstantInt>(call.getArgOperand(3));
        auto *hasLevel = dyn_cast<ConstantInt>(call.getArgOperand(5));
        auto *level = dyn_cast<ConstantFP>(call.getArgOperand(6));
        if (!normalized || !normalized->isOne() || !hasLevel || !hasLevel->isZero() ||
            !level || !level->isZero() || !isa<ConstantAggregateZero>(call.getArgOperand(4)))
            return refuse("a sample with a level, bias, offset or unnormalized coordinate this emitter does not map");
        if (args.size() != 1)
            return refuse("a sample with an argument count this emitter does not map");
        declare("uniform sampler2D " + texture->name + ";\n", texture->name);
        if (!textures_.count(texture->name)) {
            textures_.insert(texture->name);
            textureLines_.push_back("{\"name\": " + jsonQuote(texture->name) + ", \"index\": " + std::to_string(texture->index) +
                                    ", \"depth\": false, \"compare\": false}");
        }
        if (!local(call, name))
            return false;
        statement(name + " = texture2D(" + texture->name + ", " + args[0] + ");\n");
        return true;
    }

    bool emitReturn(ReturnInst &ret)
    {
        Value *value = ret.getReturnValue();
        if (!value)
            return refuse("a return with no value");
        std::vector<Value *> fields;
        if (value->getType()->isStructTy()) {
            auto found = aggregates_.find(value);
            if (found == aggregates_.end())
                return refuse("a returned aggregate this emitter does not build");
            fields = found->second;
        } else {
            fields.push_back(value);
        }
        if (fields.size() != outputs_.size())
            return refuse("a return of " + std::to_string(fields.size()) + " values for " +
                          std::to_string(outputs_.size()) + " outputs");
        bool positioned = false;
        for (size_t k = 0; k < fields.size(); k++) {
            if (!fields[k])
                return refuse("a returned field that is never set");
            const Output &output = outputs_[k];
            std::string text;
            if (output.kind == "air.position" && stage_ == Stage::Vertex) {
                if (!expression(fields[k], text))
                    return false;
                needFlip();
                statement("gl_Position = " + text + ";\n");
                statement("gl_Position.y *= revenant_flip;\n");
                positioned = true;
            } else if (output.kind == "air.vertex_output" && stage_ == Stage::Vertex) {
                std::string type = glslType(fields[k]->getType());
                if (output.name.empty() || type.empty())
                    return refuse("a vertex output without a name or of a type this emitter does not hold");
                if (!expression(fields[k], text))
                    return false;
                declare("varying " + type + " " + output.name + ";\n", output.name);
                statement(output.name + " = " + text + ";\n");
            } else if (output.kind == "air.render_target" && stage_ == Stage::Fragment && output.index == 0) {
                if (!expression(fields[k], text))
                    return false;
                statement("gl_FragColor = " + text + ";\n");
            } else {
                return refuse("an output of kind " + output.kind + " in a " +
                              (stage_ == Stage::Vertex ? "vertex" : "fragment") + " function");
            }
        }
        if (stage_ == Stage::Vertex && !positioned)
            return refuse("a vertex function that writes no position");
        return true;
    }

    std::string reflection()
    {
        std::string out = "{";
        if (stage_ == Stage::Vertex) {
            out += "\"usesVertexId\": " + std::string(declared_.count("a_vertex_id") ? "true" : "false");
            out += ", \"attributes\": [" + join(attributeLines_) + "]";
            out += ", \"inputs\": []";
            out += ", \"uniforms\": [" + join(uniformLines_) + "]";
        } else {
            std::vector<std::string> outputs;
            for (const Output &output : outputs_)
                outputs.push_back(std::to_string(output.index));
            out += "\"uniforms\": [" + join(uniformLines_) + "]";
            out += ", \"textures\": [" + join(textureLines_) + "]";
            out += ", \"sizes\": [" + join(sizes_) + "]";
            out += ", \"outputs\": [" + join(outputs) + "]";
            if (stage_ == Stage::Kernel)
                out += ", \"outputTexture\": {\"name\": " + jsonQuote(output_) + ", \"index\": " + std::to_string(outputIndex_) + "}";
            out += ", \"fetches\": []";
        }
        return out + ", \"constants\": []}";
    }

    Function &function_;
    Stage stage_;
    const DataLayout &layout_;
    std::string &refusal_;
    std::vector<Binding> bindings_;
    std::vector<unsigned> argumentNumbers_;
    std::map<const Value *, size_t> argumentSlot_;
    std::vector<Output> outputs_;
    std::map<const Value *, std::vector<Value *>> aggregates_;
    std::map<const Value *, std::string> names_;
    std::set<std::string> declared_;
    std::set<std::string> textures_;
    std::vector<std::string> declarations_;
    std::vector<std::string> locals_;
    std::vector<std::string> statements_;
    std::vector<std::string> attributeLines_;
    std::vector<std::string> uniformLines_;
    std::vector<std::string> textureLines_;
    std::vector<std::string> sizes_;
    unsigned counter_ = 0;
    unsigned depth_ = 0;
    bool returned_ = false;
    std::string output_;
    uint64_t outputIndex_ = 0;
    std::map<const Value *, Local> localPointers_;
    std::map<const Value *, const Local *> inlineLocals_;
    std::set<const BasicBlock *> visited_;
    std::map<const Function *, BlockSets> postDominators_;
    std::map<const Value *, Binding *> inlineBindings_;
    std::map<const Value *, std::string> inlineValues_;
    std::vector<Frame> frames_;
};

}

std::string jsonQuote(const std::string &text)
{
    std::string out = "\"";
    for (char c : text) {
        if (c == '"' || c == '\\') {
            out += '\\';
            out += c;
        } else if ((unsigned char)c < 0x20) {
            char escape[8];
            snprintf(escape, sizeof escape, "\\u%04x", (unsigned)(unsigned char)c);
            out += escape;
        } else {
            out += c;
        }
    }
    return out + "\"";
}

bool dumpEntry(const Entry &entry, std::string &text, std::string &error)
{
    LLVMContext context;
    auto buffer = MemoryBuffer::getMemBuffer(StringRef((const char *)entry.bitcode.data(), entry.bitcode.size()), entry.name, false);
    Expected<std::unique_ptr<Module>> parsed = parseBitcodeFile(buffer->getMemBufferRef(), context);
    if (!parsed) {
        error = "its bitcode does not read: " + toString(parsed.takeError());
        return false;
    }
    raw_string_ostream stream(text);
    (*parsed)->print(stream, nullptr);
    return true;
}

bool translateEntry(const Entry &entry, Translation &out, Refusal &refusal)
{
    out.name = entry.name;
    out.stage = entry.stage;
    refusal.name = entry.name;
    LLVMContext context;
    auto buffer = MemoryBuffer::getMemBuffer(StringRef((const char *)entry.bitcode.data(), entry.bitcode.size()), entry.name, false);
    Expected<std::unique_ptr<Module>> parsed = parseBitcodeFile(buffer->getMemBufferRef(), context);
    if (!parsed) {
        refusal.reason = "its bitcode does not read: " + toString(parsed.takeError());
        return false;
    }
    std::unique_ptr<Module> module = std::move(*parsed);
    const char *marker = entry.stage == Stage::Vertex ? "air.vertex" : entry.stage == Stage::Kernel ? "air.kernel" : "air.fragment";
    NamedMDNode *named = module->getNamedMetadata(marker);
    if (!named || named->getNumOperands() != 1) {
        refusal.reason = std::string("its module does not name it a ") + marker + " function";
        return false;
    }
    MDNode *node = named->getOperand(0);
    Function *function = node && node->getNumOperands() ? mdconst::dyn_extract<Function>(node->getOperand(0)) : nullptr;
    if (!function) {
        refusal.reason = "its stage metadata names no function";
        return false;
    }
    Shader shader(*function, entry.stage, module->getDataLayout(), refusal.reason);
    if (!shader.readInterface(node))
        return false;
    return shader.translate(out.source, out.reflection);
}

}
