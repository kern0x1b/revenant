// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "graphics/glsl_es.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <deque>
#include <map>
#include <optional>
#include <stdexcept>
#include <unordered_map>
#include <utility>

namespace shade::glsl {

std::size_t component_count(TypeId type)
{
    switch (type) {
    case TypeId::Void:
        return 0;
    case TypeId::Bool:
    case TypeId::Int:
    case TypeId::Float:
    case TypeId::Sampler2D:
        return 1;
    case TypeId::BVec2:
    case TypeId::IVec2:
    case TypeId::Vec2:
        return 2;
    case TypeId::BVec3:
    case TypeId::IVec3:
    case TypeId::Vec3:
        return 3;
    case TypeId::BVec4:
    case TypeId::IVec4:
    case TypeId::Vec4:
    case TypeId::Mat2:
        return 4;
    case TypeId::Mat3:
        return 9;
    case TypeId::Mat4:
        return 16;
    }
    return 0;
}

std::string_view type_name(TypeId type)
{
    switch (type) {
    case TypeId::Void:
        return "void";
    case TypeId::Bool:
        return "bool";
    case TypeId::BVec2:
        return "bvec2";
    case TypeId::BVec3:
        return "bvec3";
    case TypeId::BVec4:
        return "bvec4";
    case TypeId::Int:
        return "int";
    case TypeId::IVec2:
        return "ivec2";
    case TypeId::IVec3:
        return "ivec3";
    case TypeId::IVec4:
        return "ivec4";
    case TypeId::Float:
        return "float";
    case TypeId::Vec2:
        return "vec2";
    case TypeId::Vec3:
        return "vec3";
    case TypeId::Vec4:
        return "vec4";
    case TypeId::Mat2:
        return "mat2";
    case TypeId::Mat3:
        return "mat3";
    case TypeId::Mat4:
        return "mat4";
    case TypeId::Sampler2D:
        return "sampler2D";
    }
    return "?";
}

ScalarKind scalar_kind(TypeId type)
{
    switch (type) {
    case TypeId::Bool:
    case TypeId::BVec2:
    case TypeId::BVec3:
    case TypeId::BVec4:
        return ScalarKind::Bool;
    case TypeId::Int:
    case TypeId::IVec2:
    case TypeId::IVec3:
    case TypeId::IVec4:
    case TypeId::Sampler2D:
        return ScalarKind::Int;
    default:
        return ScalarKind::Float;
    }
}

bool is_matrix_type(TypeId type)
{
    return type == TypeId::Mat2 || type == TypeId::Mat3 || type == TypeId::Mat4;
}

namespace ast {

    // Declared in the order of TypeId's bool, int and float families.
    enum class Kind : std::uint8_t { Bool, Int, Float };

    constexpr bool is_matrix(TypeId type)
    {
        return type >= TypeId::Mat2 && type <= TypeId::Mat4;
    }

    constexpr bool is_vector_or_scalar(TypeId type)
    {
        return type >= TypeId::Bool && type <= TypeId::Vec4;
    }

    constexpr Kind kind_of(TypeId type)
    {
        const auto index = static_cast<int>(type);
        if (index >= 1 && index <= 4)
            return Kind::Bool;
        if (index >= 5 && index <= 8)
            return Kind::Int;
        return Kind::Float;
    }

    // The width of a vector or the order of a matrix; 1 for a scalar.
    constexpr int dimension(TypeId type)
    {
        if (is_matrix(type))
            return 2 +
                   (static_cast<int>(type) - static_cast<int>(TypeId::Mat2));
        if (is_vector_or_scalar(type))
            return (static_cast<int>(type) - 1) % 4 + 1;
        return 1;
    }

    constexpr TypeId vector_of(Kind kind, int width)
    {
        return static_cast<TypeId>(
            1 + 4 * static_cast<int>(kind) + (width - 1));
    }

    constexpr int count_of(TypeId type)
    {
        return static_cast<int>(component_count(type));
    }

    Value make(TypeId type)
    {
        Value value;
        value.type = type;
        return value;
    }

    Value make_float(float x)
    {
        Value value = make(TypeId::Float);
        value.v[0] = x;
        return value;
    }

    Value make_bool(bool x)
    {
        Value value = make(TypeId::Bool);
        value.v[0] = x ? 1.0F : 0.0F;
        return value;
    }

    enum class Op : std::uint8_t {
        None,
        Add,
        Sub,
        Mul,
        Div,
        Lt,
        Gt,
        Le,
        Ge,
        Eq,
        Ne,
        And,
        Or,
        Xor,
        Neg,
        Plus,
        Not,
    };

    enum class Builtin : std::uint8_t {
        Radians,
        Degrees,
        Sin,
        Cos,
        Tan,
        Asin,
        Acos,
        Atan,
        Pow,
        Exp,
        Log,
        Exp2,
        Log2,
        Sqrt,
        Inversesqrt,
        Abs,
        Sign,
        Floor,
        Ceil,
        Fract,
        Mod,
        Min,
        Max,
        Clamp,
        Mix,
        Step,
        Smoothstep,
        Length,
        Distance,
        Dot,
        Cross,
        Normalize,
        Faceforward,
        Reflect,
        Refract,
        MatrixCompMult,
        LessThan,
        LessThanEqual,
        GreaterThan,
        GreaterThanEqual,
        Equal,
        NotEqual,
        Any,
        All,
        Not,
        Texture2D,
        Texture2DProj,
        Texture2DLod,
        Texture2DProjLod,
    };

    const std::unordered_map<std::string_view, Builtin>& builtin_names()
    {
        static const std::unordered_map<std::string_view, Builtin> names {
            { "radians", Builtin::Radians },
            { "degrees", Builtin::Degrees },
            { "sin", Builtin::Sin },
            { "cos", Builtin::Cos },
            { "tan", Builtin::Tan },
            { "asin", Builtin::Asin },
            { "acos", Builtin::Acos },
            { "atan", Builtin::Atan },
            { "pow", Builtin::Pow },
            { "exp", Builtin::Exp },
            { "log", Builtin::Log },
            { "exp2", Builtin::Exp2 },
            { "log2", Builtin::Log2 },
            { "sqrt", Builtin::Sqrt },
            { "inversesqrt", Builtin::Inversesqrt },
            { "abs", Builtin::Abs },
            { "sign", Builtin::Sign },
            { "floor", Builtin::Floor },
            { "ceil", Builtin::Ceil },
            { "fract", Builtin::Fract },
            { "mod", Builtin::Mod },
            { "min", Builtin::Min },
            { "max", Builtin::Max },
            { "clamp", Builtin::Clamp },
            { "mix", Builtin::Mix },
            { "step", Builtin::Step },
            { "smoothstep", Builtin::Smoothstep },
            { "length", Builtin::Length },
            { "distance", Builtin::Distance },
            { "dot", Builtin::Dot },
            { "cross", Builtin::Cross },
            { "normalize", Builtin::Normalize },
            { "faceforward", Builtin::Faceforward },
            { "reflect", Builtin::Reflect },
            { "refract", Builtin::Refract },
            { "matrixCompMult", Builtin::MatrixCompMult },
            { "lessThan", Builtin::LessThan },
            { "lessThanEqual", Builtin::LessThanEqual },
            { "greaterThan", Builtin::GreaterThan },
            { "greaterThanEqual", Builtin::GreaterThanEqual },
            { "equal", Builtin::Equal },
            { "notEqual", Builtin::NotEqual },
            { "any", Builtin::Any },
            { "all", Builtin::All },
            { "not", Builtin::Not },
            { "texture2D", Builtin::Texture2D },
            { "texture2DProj", Builtin::Texture2DProj },
            { "texture2DLod", Builtin::Texture2DLod },
            { "texture2DProjLod", Builtin::Texture2DProjLod },
        };
        return names;
    }

    struct Function;

    struct Node {
        enum class Type : std::uint8_t {
            Literal,
            Variable,
            Unary,
            Binary,
            Logical,
            Assign,
            Conditional,
            Call,
            Builtin,
            Construct,
            Index,
            Swizzle,
            Increment,
            Sequence,
        };

        Type type { Type::Literal };
        int line { };
        Value literal;
        bool global { };
        bool read_only { };
        bool prefix { };
        bool array_index { };
        std::uint32_t slot { };
        std::uint32_t array_size { };
        Op op { Op::None };
        TypeId construct { TypeId::Void };
        ast::Builtin builtin { ast::Builtin::Radians };
        std::array<std::uint8_t, 4> swizzle { };
        std::uint8_t swizzle_count { };
        const std::vector<Function*>* overloads { };
        std::string name;
        std::vector<std::unique_ptr<Node>> args;
        // 1 for a leaf, else one more than the tallest argument.
        std::uint16_t height { 1 };
    };

    struct Statement {
        enum class Type : std::uint8_t {
            Block,
            Declare,
            Expression,
            If,
            For,
            While,
            DoWhile,
            Return,
            Break,
            Continue,
            Discard,
        };

        Type type { Type::Block };
        int line { };
        TypeId declared { TypeId::Void };
        std::uint32_t slot { };
        std::uint32_t array_size { };
        std::unique_ptr<Node> expression;
        std::unique_ptr<Node> step;
        std::vector<std::unique_ptr<Statement>> children;
    };

    struct Parameter {
        enum class Direction : std::uint8_t { In, Out, InOut };

        TypeId type { TypeId::Void };
        Direction direction { Direction::In };
        std::uint32_t slot { };
    };

    struct Function {
        std::string name;
        TypeId result { TypeId::Void };
        std::vector<Parameter> parameters;
        std::unique_ptr<Statement> body;
        std::uint32_t frame_size { };
    };

    struct GlobalInitializer {
        std::uint32_t slot { };
        TypeId type { TypeId::Void };
        std::unique_ptr<Node> value;
    };

} // namespace ast

struct Module::Impl {
    Stage stage { Stage::Vertex };
    std::vector<Variable> variables;
    std::vector<Value> initial_globals;
    std::vector<ast::GlobalInitializer> initializers;
    std::vector<std::unique_ptr<ast::Function>> functions;
    std::map<std::string, std::vector<ast::Function*>, std::less<>> overloads;
    ast::Function* main { };
    // The slots of the built-ins a shader writes, cleared before every run.
    std::vector<std::uint32_t> output_slots;
};

namespace {

    // A float as an int, for what an index or a size takes: a value that is
    // not a number or lies outside the range of an int is clamped, never cast
    // as it is.
    int clamped_int(double x)
    {
        constexpr double limit = 2147483520.0;
        if (!(x == x))
            return 0;
        return static_cast<int>(std::clamp(x, -limit, limit));
    }

    // The values one call's locals may take on the run's stack; the stack
    // holds this many in all (main's frame and every active call's).
    constexpr std::uint32_t stack_values = 1024;

    // What macro expansion may produce. Both bounds are far above any shader
    // of the era (the compositor's are a few hundred tokens) and keep a guest's
    // macros from growing the host's memory or time without limit: a macro
    // that expands to sixteen copies of another, eight deep, is 16^8 tokens
    // from a few hundred bytes of source.
    constexpr std::size_t maximum_tokens = 65536;

    // How deeply the arguments of macro calls may contain macro calls.
    constexpr int maximum_expansion_depth = 16;

    // How deep a shader may nest, in what the compiler and the run recurse
    // through. A guest chooses the shape of its source, and a few thousand
    // tokens of "(" or "{" or "a+a+a+..." would take a host thread's stack
    // (a guest's GL calls run on a thread with the default 512 KB). The parser
    // recurses at most maximum_parse_nesting levels of statements and
    // expressions; a tree is at most maximum_tree_height tall, so building,
    // running and destroying it recurse as far; and a run, whatever the calls
    // between, nests at most maximum_run_nesting evaluations and statements.
    constexpr int maximum_parse_nesting = 32;
    constexpr std::uint16_t maximum_tree_height = 128;
    constexpr std::uint32_t maximum_run_nesting = 256;

    // The values of a shader's globals, attributes, uniforms and varyings
    // together (an array counts its length; a matrix is one value). Every
    // instance of a module holds a copy, and a guest can declare thousands of
    // arrays of 256 in a few kilobytes of source.
    constexpr std::size_t maximum_global_values = 4096;
    constexpr std::size_t maximum_scanned_bytes = 4U * 1024U * 1024U;

    struct CompileError {
        int line { };
        std::string message;
    };

    [[noreturn]] void refuse(int line, std::string message)
    {
        throw CompileError { line, std::move(message) };
    }

    struct Token {
        enum class Type : std::uint8_t {
            Identifier,
            Integer,
            Number,
            Punct,
            End
        };

        Type type { Type::End };
        std::string text;
        double number { };
        int line { };
    };

    bool identifier_start(char c)
    {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
    }

    bool digit(char c) { return c >= '0' && c <= '9'; }

    // Turns GLSL ES source into tokens. The preprocessor is the subset shaders
    // use in practice: #version, #extension and #pragma (ignored); #define and
    // #undef of object-like and function-like macros, as C++ defines them
    // (without # stringizing, which GLSL ES has no strings for); and #if,
    // #ifdef, #ifndef, #else and #endif over defined(NAME), NAME, 0 and 1.
    class Lexer {
    public:
        explicit Lexer(std::string_view source)
            : source_(source)
        {
            macros_["GL_ES"] = Macro { false, {}, body_of("1", 1) };
        }

        std::vector<Token> run()
        {
            items_ = lex(source_, 1, false);
            Stream source;
            source.from_source = true;
            std::vector<Piece> out;
            expand(source, out, 0);
            if (!conditions_.empty())
                refuse(line_, "#if without #endif");
            std::vector<Token> tokens;
            tokens.reserve(out.size() + 1);
            for (auto& piece : out)
                tokens.push_back(std::move(piece.token));
            Token end;
            end.line = line_;
            tokens.push_back(end);
            return tokens;
        }

    private:
        struct Condition {
            bool parent_active { };
            bool taken { };
            bool active { };
        };

        // What the lexer reads from the source: a token, or a directive (its
        // text after the '#', in token.text).
        struct Item {
            bool directive { };
            Token token;
        };

        // A token that expansion may hide. A macro's name inside its own
        // expansion is an ordinary identifier, so each piece carries the names
        // it may not expand.
        struct Piece {
            Token token;
            std::vector<std::string> hidden;
        };

        // What expansion reads: the pieces pushed back first, then the source
        // (the arguments of a call are a stream of their own, with no source).
        struct Stream {
            std::deque<Piece> pushed;
            bool from_source { };
        };

        struct Macro {
            bool function_like { };
            std::vector<std::string> parameters;
            std::vector<Token> body;
        };

        bool active() const
        {
            return conditions_.empty() || conditions_.back().active;
        }

        // Tokenizes text. A macro's body is tokenized with body set: it has no
        // directives, and # and ## are punctuation.
        std::vector<Item> lex(std::string_view text, int first_line, bool body)
        {
            std::vector<Item> items;
            std::size_t i = 0;
            int line = first_line;
            bool line_start = true;
            auto push = [&](Token::Type type, std::string value,
                            double number) {
                Item item;
                item.token.type = type;
                item.token.text = std::move(value);
                item.token.number = number;
                item.token.line = line;
                items.push_back(std::move(item));
            };
            while (i < text.size()) {
                const char c = text[i];
                if (c == '\n') {
                    ++line;
                    ++i;
                    line_start = true;
                    continue;
                }
                if (c == ' ' || c == '\t' || c == '\r') {
                    ++i;
                    continue;
                }
                if (c == '/' && i + 1 < text.size() && text[i + 1] == '/') {
                    while (i < text.size() && text[i] != '\n')
                        ++i;
                    continue;
                }
                if (c == '/' && i + 1 < text.size() && text[i + 1] == '*') {
                    i += 2;
                    while (i + 1 < text.size() &&
                           !(text[i] == '*' && text[i + 1] == '/')) {
                        if (text[i] == '\n')
                            ++line;
                        ++i;
                    }
                    if (i + 1 >= text.size())
                        refuse(line, "unterminated comment");
                    i += 2;
                    continue;
                }
                if (c == '#' && line_start && !body) {
                    std::size_t end = i;
                    while (end < text.size() && text[end] != '\n')
                        ++end;
                    Item item;
                    item.directive = true;
                    item.token.text = std::string { text.substr(i + 1, end - i - 1) };
                    item.token.line = line;
                    items.push_back(std::move(item));
                    i = end;
                    continue;
                }
                line_start = false;
                if (identifier_start(c)) {
                    std::size_t end = i;
                    while (end < text.size() &&
                           (identifier_start(text[end]) || digit(text[end])))
                        ++end;
                    push(Token::Type::Identifier,
                        std::string { text.substr(i, end - i) }, 0.0);
                    i = end;
                    continue;
                }
                if (digit(c) ||
                    (c == '.' && i + 1 < text.size() && digit(text[i + 1]))) {
                    std::size_t end = i;
                    bool real = false;
                    if (c == '0' && i + 1 < text.size() &&
                        (text[i + 1] == 'x' || text[i + 1] == 'X')) {
                        end = i + 2;
                        while (end < text.size() &&
                               std::isxdigit(
                                   static_cast<unsigned char>(text[end])) != 0)
                            ++end;
                    } else {
                        while (end < text.size() && digit(text[end]))
                            ++end;
                        if (end < text.size() && text[end] == '.') {
                            real = true;
                            ++end;
                            while (end < text.size() && digit(text[end]))
                                ++end;
                        }
                        if (end < text.size() &&
                            (text[end] == 'e' || text[end] == 'E')) {
                            auto exponent = end + 1;
                            if (exponent < text.size() &&
                                (text[exponent] == '+' ||
                                    text[exponent] == '-'))
                                ++exponent;
                            if (exponent < text.size() &&
                                digit(text[exponent])) {
                                real = true;
                                end = exponent;
                                while (end < text.size() && digit(text[end]))
                                    ++end;
                            }
                        }
                    }
                    if (end < text.size() &&
                        (identifier_start(text[end]) || digit(text[end])))
                        refuse(line, "invalid number suffix");
                    const std::string spelled { text.substr(i, end - i) };
                    i = end;
                    push(real ? Token::Type::Number : Token::Type::Integer,
                        spelled, std::strtod(spelled.c_str(), nullptr));
                    continue;
                }
                static constexpr std::string_view pairs[] = { "++", "--",
                    "+=", "-=", "*=", "/=", "==", "!=", "<=", ">=", "&&", "||",
                    "^^" };
                if (i + 1 < text.size()) {
                    const auto two = text.substr(i, 2);
                    if (std::find(std::begin(pairs), std::end(pairs), two) !=
                        std::end(pairs)) {
                        push(Token::Type::Punct, std::string { two }, 0.0);
                        i += 2;
                        continue;
                    }
                }
                if (body && c == '#') {
                    const bool paste = i + 1 < text.size() && text[i + 1] == '#';
                    push(Token::Type::Punct, paste ? "##" : "#", 0.0);
                    i += paste ? 2 : 1;
                    continue;
                }
                static constexpr std::string_view singles =
                    "+-*/<>=!?:;,.(){}[]";
                if (singles.find(c) == std::string_view::npos)
                    refuse(line,
                        std::string { "unsupported or reserved character '" } +
                            c + "'");
                push(Token::Type::Punct, std::string(1, c), 0.0);
                ++i;
            }
            if (!body)
                line_ = line;
            return items;
        }

        std::vector<Token> body_of(std::string_view text, int line)
        {
            std::vector<Token> tokens;
            for (auto& item : lex(text, line, true))
                tokens.push_back(std::move(item.token));
            return tokens;
        }

        // The next piece of a stream. The source runs each directive as it
        // reaches it and skips the tokens that a false condition hides; a
        // stream that is used up gives an End token.
        Piece next(Stream& stream)
        {
            if (!stream.pushed.empty()) {
                Piece piece = std::move(stream.pushed.front());
                stream.pushed.pop_front();
                return piece;
            }
            while (stream.from_source && next_item_ < items_.size()) {
                const auto& item = items_[next_item_++];
                if (item.directive) {
                    directive(item.token.text, item.token.line);
                } else if (active()) {
                    Piece piece;
                    piece.token = item.token;
                    return piece;
                }
            }
            Piece end;
            end.token.type = Token::Type::End;
            end.token.line = line_;
            return end;
        }

        static void push_front(Stream& stream, std::vector<Piece> pieces)
        {
            stream.pushed.insert(stream.pushed.begin(),
                std::make_move_iterator(pieces.begin()),
                std::make_move_iterator(pieces.end()));
        }

        static void emit(std::vector<Piece>& out, Piece piece)
        {
            if (out.size() >= maximum_tokens)
                refuse(piece.token.line, "the shader expands to too many tokens");
            out.push_back(std::move(piece));
        }

        // Expands a stream into out. A macro's name is replaced by its body,
        // which is read again with the name hidden from it. depth counts the
        // expansions of arguments that this one is inside.
        void expand(Stream& stream, std::vector<Piece>& out, int depth)
        {
            for (;;) {
                Piece piece = next(stream);
                if (piece.token.type == Token::Type::End)
                    return;
                const auto found = piece.token.type == Token::Type::Identifier
                    ? macros_.find(piece.token.text)
                    : macros_.end();
                if (found == macros_.end() || hides(piece, found->first)) {
                    emit(out, std::move(piece));
                    continue;
                }
                // Copied, because reading the arguments may run a #undef.
                const std::string name = found->first;
                const Macro macro = found->second;
                if (!macro.function_like) {
                    auto hidden = piece.hidden;
                    hidden.push_back(name);
                    push_front(stream,
                        substitute(macro, {}, {}, hidden, piece.token.line));
                    continue;
                }
                Piece open = next(stream);
                if (!is_punct(open.token, "(")) {
                    push_front(stream, { std::move(open) });
                    emit(out, std::move(piece));
                    continue;
                }
                std::vector<std::vector<Piece>> arguments(1);
                int nesting = 0;
                Piece close;
                for (;;) {
                    Piece argument = next(stream);
                    if (argument.token.type == Token::Type::End)
                        refuse(piece.token.line,
                            "the arguments of '" + name + "' are not closed");
                    if (is_punct(argument.token, "(")) {
                        ++nesting;
                    } else if (is_punct(argument.token, ")")) {
                        if (nesting == 0) {
                            close = std::move(argument);
                            break;
                        }
                        --nesting;
                    } else if (is_punct(argument.token, ",") && nesting == 0) {
                        arguments.emplace_back();
                        continue;
                    }
                    arguments.back().push_back(std::move(argument));
                }
                if (arguments.size() == 1 && arguments.front().empty() &&
                    macro.parameters.empty())
                    arguments.clear();
                if (arguments.size() != macro.parameters.size())
                    refuse(piece.token.line,
                        "'" + name + "' takes " +
                            std::to_string(macro.parameters.size()) +
                            " arguments, not " +
                            std::to_string(arguments.size()));
                if (depth >= maximum_expansion_depth)
                    refuse(piece.token.line, "macro expansion is too deep");
                std::vector<std::vector<Piece>> expanded;
                for (const auto& argument : arguments) {
                    Stream alone;
                    alone.pushed.assign(argument.begin(), argument.end());
                    std::vector<Piece> result;
                    expand(alone, result, depth + 1);
                    expanded.push_back(std::move(result));
                }
                auto hidden = intersection(piece.hidden, close.hidden);
                hidden.push_back(name);
                push_front(stream,
                    substitute(macro, arguments, expanded, hidden,
                        piece.token.line));
            }
        }

        // The body of a macro with its parameters replaced. An argument is
        // expanded first, unless ## joins it to a neighbour; ## pastes the
        // tokens on either side of it. Every piece of the result hides names.
        std::vector<Piece> substitute(const Macro& macro,
            const std::vector<std::vector<Piece>>& arguments,
            const std::vector<std::vector<Piece>>& expanded,
            const std::vector<std::string>& hidden, int line)
        {
            // Every invocation is charged, even one whose body is empty: a
            // macro that expands to nothing sixteen times, eight deep, is
            // 16^8 invocations.
            work_ += macro.body.size() + 1;
            if (work_ > maximum_scanned_bytes)
                refuse(line, "the shader's macros expand to too much text");
            std::vector<Piece> out;
            const auto& body = macro.body;
            bool pasting = false;
            // Whether out ends with an operand that a following ## pastes onto.
            bool joinable = false;
            for (std::size_t i = 0; i < body.size(); ++i) {
                const auto& token = body[i];
                if (is_punct(token, "##")) {
                    if (i == 0 || i + 1 == body.size() ||
                        is_punct(body[i - 1], "##"))
                        refuse(line, "## must join two tokens of a macro's body");
                    pasting = true;
                    continue;
                }
                if (is_punct(token, "#"))
                    refuse(line,
                        "# is not supported: GLSL ES has no strings to make");
                const bool paste = pasting;
                pasting = false;
                std::vector<Piece> pieces;
                const auto parameter = parameter_index(macro, token);
                if (parameter) {
                    const bool joined =
                        (i > 0 && is_punct(body[i - 1], "##")) ||
                        (i + 1 < body.size() && is_punct(body[i + 1], "##"));
                    pieces = joined ? arguments[*parameter]
                                    : expanded[*parameter];
                } else {
                    Piece piece;
                    piece.token = token;
                    piece.token.line = line;
                    pieces.push_back(std::move(piece));
                }
                for (auto& piece : pieces)
                    for (const auto& name : hidden)
                        if (!listed(piece.hidden, name))
                            piece.hidden.push_back(name);
                if (pieces.empty()) {
                    if (!paste)
                        joinable = false;
                    continue;
                }
                if (paste && joinable) {
                    out.back() = glue(out.back(), pieces.front(), line);
                    pieces.erase(pieces.begin());
                }
                for (auto& piece : pieces) {
                    work_ += piece.token.text.size() + 1;
                    if (work_ > maximum_scanned_bytes)
                        refuse(line,
                            "the shader's macros expand to too much text");
                    out.push_back(std::move(piece));
                }
                joinable = true;
            }
            return out;
        }

        // The token ## makes of two: their spellings written together, read
        // again as one token.
        Piece glue(const Piece& left, const Piece& right, int line)
        {
            const auto spelled = left.token.text + right.token.text;
            auto items = lex(spelled, line, true);
            if (items.size() != 1)
                refuse(line,
                    "'" + spelled + "' is not one token, so ## cannot paste it");
            Piece result;
            result.token = std::move(items.front().token);
            result.hidden = left.hidden;
            for (const auto& name : right.hidden)
                if (!listed(result.hidden, name))
                    result.hidden.push_back(name);
            return result;
        }

        static bool is_punct(const Token& token, std::string_view text)
        {
            return token.type == Token::Type::Punct && token.text == text;
        }

        static bool listed(const std::vector<std::string>& names,
            const std::string& name)
        {
            return std::find(names.begin(), names.end(), name) != names.end();
        }

        static bool hides(const Piece& piece, const std::string& name)
        {
            return listed(piece.hidden, name);
        }

        static std::vector<std::string> intersection(
            const std::vector<std::string>& first,
            const std::vector<std::string>& second)
        {
            std::vector<std::string> result;
            for (const auto& name : first)
                if (listed(second, name))
                    result.push_back(name);
            return result;
        }

        static std::optional<std::size_t> parameter_index(
            const Macro& macro, const Token& token)
        {
            if (token.type != Token::Type::Identifier)
                return std::nullopt;
            const auto found = std::find(macro.parameters.begin(),
                macro.parameters.end(), token.text);
            if (found == macro.parameters.end())
                return std::nullopt;
            return static_cast<std::size_t>(found - macro.parameters.begin());
        }

        // The names of a function-like macro's parameters, from the text
        // between its parentheses.
        static std::vector<std::string> parameters(
            std::string_view list, int line)
        {
            std::vector<std::string> result;
            std::size_t i = 0;
            const auto skip_spaces = [&] {
                while (i < list.size() &&
                       (list[i] == ' ' || list[i] == '\t' || list[i] == '\r'))
                    ++i;
            };
            skip_spaces();
            if (i == list.size())
                return result;
            for (;;) {
                skip_spaces();
                if (i == list.size() || !identifier_start(list[i]))
                    refuse(line, "malformed macro parameters");
                std::size_t end = i;
                while (end < list.size() &&
                       (identifier_start(list[end]) || digit(list[end])))
                    ++end;
                std::string name { list.substr(i, end - i) };
                if (listed(result, name))
                    refuse(line, "'" + name + "' is a macro parameter twice");
                result.push_back(name);
                i = end;
                skip_spaces();
                if (i == list.size())
                    return result;
                if (list[i] != ',')
                    refuse(line, "malformed macro parameters");
                ++i;
            }
        }

        static std::vector<std::string> words(std::string_view text)
        {
            std::vector<std::string> result;
            std::string current;
            auto flush = [&] {
                if (!current.empty())
                    result.push_back(std::move(current));
                current.clear();
            };
            for (const char c : text) {
                if (c == ' ' || c == '\t' || c == '\r') {
                    flush();
                } else if (c == '(' || c == ')' || c == '!') {
                    flush();
                    result.emplace_back(1, c);
                } else {
                    current += c;
                }
            }
            flush();
            return result;
        }

        bool evaluate(const std::vector<std::string>& w, std::size_t first,
            int line) const
        {
            const auto value = [&](std::size_t& at) -> bool {
                bool negate = false;
                while (at < w.size() && w[at] == "!") {
                    negate = !negate;
                    ++at;
                }
                if (at >= w.size())
                    refuse(line, "malformed #if");
                bool result = false;
                if (w[at] == "defined") {
                    ++at;
                    const bool paren = at < w.size() && w[at] == "(";
                    if (paren)
                        ++at;
                    if (at >= w.size())
                        refuse(line, "malformed #if defined");
                    result = macros_.contains(w[at]);
                    ++at;
                    if (paren) {
                        if (at >= w.size() || w[at] != ")")
                            refuse(line, "malformed #if defined");
                        ++at;
                    }
                } else if (w[at] == "0" || w[at] == "1") {
                    result = w[at] == "1";
                    ++at;
                } else {
                    refuse(line,
                        "#if supports defined(NAME), 0 and 1 only, got '" +
                            w[at] + "'");
                }
                return negate ? !result : result;
            };
            auto at = first;
            bool result = value(at);
            while (at < w.size()) {
                if (w[at] != "&&" && w[at] != "||")
                    refuse(line, "malformed #if");
                const bool conjunction = w[at] == "&&";
                ++at;
                const bool next = value(at);
                result = conjunction ? (result && next) : (result || next);
            }
            return result;
        }

        void directive(std::string_view text, int line)
        {
            const auto w = words(text);
            if (w.empty())
                return;
            const auto& name = w[0];
            if (name == "if" || name == "ifdef" || name == "ifndef") {
                Condition condition;
                condition.parent_active = active();
                bool value = false;
                if (condition.parent_active) {
                    if (name == "if") {
                        value = evaluate(w, 1, line);
                    } else {
                        if (w.size() < 2)
                            refuse(line, "#" + name + " needs a name");
                        value = macros_.contains(w[1]) == (name == "ifdef");
                    }
                }
                condition.taken = value;
                condition.active = condition.parent_active && value;
                conditions_.push_back(condition);
                return;
            }
            if (name == "else") {
                if (conditions_.empty())
                    refuse(line, "#else without #if");
                auto& condition = conditions_.back();
                condition.active = condition.parent_active && !condition.taken;
                condition.taken = true;
                return;
            }
            if (name == "endif") {
                if (conditions_.empty())
                    refuse(line, "#endif without #if");
                conditions_.pop_back();
                return;
            }
            if (!active())
                return;
            if (name == "version" || name == "extension" || name == "pragma")
                return;
            if (name == "define") {
                if (w.size() < 2 || !identifier_start(w[1].front()))
                    refuse(line, "#define needs a name");
                // The name is the first word after the keyword. Searching the
                // text for it would find a letter inside "define" first.
                const auto at = text.find_first_not_of(
                    " \t\r", text.find(name) + name.size());
                const auto after = at + w[1].size();
                Macro macro;
                std::string_view body = text.substr(after);
                if (after < text.size() && text[after] == '(') {
                    macro.function_like = true;
                    const auto close = text.find(')', after);
                    if (close == std::string_view::npos)
                        refuse(line, "malformed macro parameters");
                    macro.parameters = parameters(
                        text.substr(after + 1, close - after - 1), line);
                    body = text.substr(close + 1);
                }
                macro.body = body_of(body, line);
                macros_[w[1]] = std::move(macro);
                return;
            }
            if (name == "undef") {
                if (w.size() < 2)
                    refuse(line, "#undef needs a name");
                macros_.erase(w[1]);
                return;
            }
            refuse(line, "unsupported directive #" + name);
        }

        std::string_view source_;
        std::map<std::string, Macro> macros_;
        std::vector<Condition> conditions_;
        std::vector<Item> items_;
        std::size_t next_item_ { };
        std::size_t work_ { };
        int line_ { 1 };
    };

    std::optional<TypeId> type_from_name(std::string_view name)
    {
        static const std::unordered_map<std::string_view, TypeId> types {
            { "void", TypeId::Void },
            { "bool", TypeId::Bool },
            { "bvec2", TypeId::BVec2 },
            { "bvec3", TypeId::BVec3 },
            { "bvec4", TypeId::BVec4 },
            { "int", TypeId::Int },
            { "ivec2", TypeId::IVec2 },
            { "ivec3", TypeId::IVec3 },
            { "ivec4", TypeId::IVec4 },
            { "float", TypeId::Float },
            { "vec2", TypeId::Vec2 },
            { "vec3", TypeId::Vec3 },
            { "vec4", TypeId::Vec4 },
            { "mat2", TypeId::Mat2 },
            { "mat3", TypeId::Mat3 },
            { "mat4", TypeId::Mat4 },
            { "sampler2D", TypeId::Sampler2D },
        };
        const auto found = types.find(name);
        if (found == types.end())
            return std::nullopt;
        return found->second;
    }

    struct Symbol {
        TypeId type { TypeId::Void };
        std::uint32_t array_size { };
        std::uint32_t slot { };
        bool global { };
        bool read_only { };
        std::optional<int> constant;
    };

    class Parser {
    public:
        Parser(std::vector<Token> tokens, Stage stage, Module::Impl& impl)
            : tokens_(std::move(tokens))
            , stage_(stage)
            , impl_(impl)
        {
            scopes_.emplace_back();
            impl_.stage = stage;
            if (stage == Stage::Vertex) {
                builtin_variable("gl_Position", TypeId::Vec4, false);
                builtin_variable("gl_PointSize", TypeId::Float, false);
            } else {
                builtin_variable("gl_FragColor", TypeId::Vec4, false);
                builtin_variable("gl_FragCoord", TypeId::Vec4, true);
                builtin_variable("gl_FrontFacing", TypeId::Bool, true);
                builtin_variable("gl_PointCoord", TypeId::Vec2, true);
                declare_global(
                    "gl_FragData", TypeId::Vec4, 1, Storage::Builtin, false);
            }
        }

        void unit()
        {
            while (peek().type != Token::Type::End)
                external_declaration();
            if (impl_.main == nullptr)
                refuse(peek().line, "no void main() in the shader");
        }

    private:
        const Token& peek(std::size_t ahead = 0) const
        {
            return tokens_[std::min(at_ + ahead, tokens_.size() - 1)];
        }

        bool is_punct(std::string_view text, std::size_t ahead = 0) const
        {
            const auto& token = peek(ahead);
            return token.type == Token::Type::Punct && token.text == text;
        }

        bool is_word(std::string_view text, std::size_t ahead = 0) const
        {
            const auto& token = peek(ahead);
            return token.type == Token::Type::Identifier && token.text == text;
        }

        bool accept(std::string_view text)
        {
            if (!is_punct(text))
                return false;
            ++at_;
            return true;
        }

        bool accept_word(std::string_view text)
        {
            if (!is_word(text))
                return false;
            ++at_;
            return true;
        }

        void expect(std::string_view text)
        {
            if (!accept(text))
                refuse(peek().line, "expected '" + std::string { text } +
                                        "' before '" + peek().text + "'");
        }

        std::string identifier()
        {
            const auto& token = peek();
            if (token.type != Token::Type::Identifier)
                refuse(token.line, "expected an identifier");
            ++at_;
            return token.text;
        }

        static bool precision_word(std::string_view word)
        {
            return word == "highp" || word == "mediump" || word == "lowp";
        }

        std::optional<TypeId> peek_type(std::size_t ahead = 0) const
        {
            const auto& token = peek(ahead);
            if (token.type != Token::Type::Identifier)
                return std::nullopt;
            return type_from_name(token.text);
        }

        static bool unsupported_word(std::string_view word)
        {
            return word == "struct" || word == "samplerCube" ||
                   word == "sampler3D" || word == "sampler2DRect";
        }

        // Symbols ------------------------------------------------------------

        const Symbol* lookup(const std::string& name) const
        {
            for (auto scope = scopes_.rbegin(); scope != scopes_.rend();
                ++scope) {
                const auto found = scope->find(name);
                if (found != scope->end())
                    return &found->second;
            }
            return nullptr;
        }

        std::uint32_t allocate_global(TypeId type, std::uint32_t count)
        {
            const auto slot =
                static_cast<std::uint32_t>(impl_.initial_globals.size());
            if (count > maximum_global_values - impl_.initial_globals.size())
                refuse(peek().line, "the shader's global variables need more "
                                    "than " +
                                        std::to_string(maximum_global_values) +
                                        " values of storage");
            for (std::uint32_t i = 0; i < count; ++i)
                impl_.initial_globals.push_back(ast::make(type));
            return slot;
        }

        // A global with a storage class (or a built-in) is part of the module's
        // interface; a plain global is private to the shader.
        std::uint32_t declare_global(const std::string& name, TypeId type,
            std::uint32_t array_size, std::optional<Storage> storage,
            bool read_only)
        {
            const auto slot = allocate_global(type, std::max(array_size, 1U));
            Symbol symbol;
            symbol.type = type;
            symbol.array_size = array_size;
            symbol.slot = slot;
            symbol.global = true;
            symbol.read_only = read_only;
            scopes_.front()[name] = symbol;
            if (storage) {
                Variable variable;
                variable.name = name;
                variable.type = type;
                variable.array_size = array_size;
                variable.storage = *storage;
                variable.slot = slot;
                impl_.variables.push_back(std::move(variable));
            }
            return slot;
        }

        void builtin_variable(
            const std::string& name, TypeId type, bool read_only)
        {
            declare_global(name, type, 0, Storage::Builtin, read_only);
        }

        // Gives the function being parsed count more values of frame. A frame
        // that cannot fit the run's stack is refused here, where the guest's
        // declaration is, never at run time after a write has gone past it.
        void reserve(std::uint32_t count, int line)
        {
            if (count > stack_values - frame_size_)
                refuse(line, "the variables of '" + function_name_ +
                                 "' need more than " +
                                 std::to_string(stack_values) +
                                 " values of local storage");
            frame_size_ += count;
        }

        Symbol declare_local(
            const std::string& name, TypeId type, std::uint32_t array_size)
        {
            auto& scope = scopes_.back();
            if (scope.contains(name))
                refuse(peek().line, "'" + name + "' is already declared");
            Symbol symbol;
            symbol.type = type;
            symbol.array_size = array_size;
            symbol.slot = frame_size_;
            reserve(std::max(array_size, 1U), peek().line);
            scope[name] = symbol;
            return symbol;
        }

        // Declarations -------------------------------------------------------

        void skip_precision()
        {
            if (peek().type == Token::Type::Identifier &&
                precision_word(peek().text))
                ++at_;
        }

        std::uint32_t array_suffix()
        {
            if (!accept("["))
                return 0;
            const auto& token = peek();
            std::optional<int> size;
            if (token.type == Token::Type::Integer) {
                size = clamped_int(token.number);
                ++at_;
            } else if (token.type == Token::Type::Identifier) {
                const auto* symbol = lookup(token.text);
                if (symbol != nullptr && symbol->constant)
                    size = symbol->constant;
                ++at_;
            }
            if (!size || *size < 1 || *size > 256)
                refuse(
                    token.line, "an array size must be a constant in 1..256");
            expect("]");
            return static_cast<std::uint32_t>(*size);
        }

        void external_declaration()
        {
            const int line = peek().line;
            if (accept_word("precision")) {
                skip_precision();
                if (!peek_type())
                    refuse(line, "precision needs a type");
                ++at_;
                expect(";");
                return;
            }
            accept_word("invariant");
            std::optional<Storage> storage;
            bool constant = false;
            if (accept_word("const")) {
                constant = true;
            } else if (accept_word("attribute")) {
                storage = Storage::Attribute;
            } else if (accept_word("uniform")) {
                storage = Storage::Uniform;
            } else if (accept_word("varying")) {
                storage = Storage::Varying;
            }
            skip_precision();
            if (peek().type == Token::Type::Identifier &&
                unsupported_word(peek().text))
                refuse(line, "'" + peek().text + "' is not supported");
            const auto type = peek_type();
            if (!type)
                refuse(line,
                    "expected a declaration before '" + peek().text + "'");
            ++at_;
            if (!storage && !constant &&
                peek().type == Token::Type::Identifier && is_punct("(", 1)) {
                function(*type);
                return;
            }
            if (*type == TypeId::Void)
                refuse(line, "a variable cannot be void");
            if (storage == Storage::Attribute && stage_ != Stage::Vertex)
                refuse(line, "attribute in a fragment shader");
            if (*type == TypeId::Sampler2D && storage != Storage::Uniform)
                refuse(line, "a sampler must be a uniform");
            if (storage && *storage != Storage::Uniform &&
                (ast::kind_of(*type) != ast::Kind::Float ||
                    *type == TypeId::Sampler2D))
                refuse(line, "attributes and varyings are float-based");
            do {
                const auto name = identifier();
                if (name.starts_with("gl_"))
                    refuse(line, "'" + name + "' uses the reserved prefix gl_");
                if (scopes_.front().contains(name))
                    refuse(line, "'" + name + "' is already declared");
                const auto array_size = array_suffix();
                std::unique_ptr<ast::Node> init;
                std::optional<int> folded;
                if (accept("=")) {
                    if (storage)
                        refuse(line, "this storage class takes no initializer");
                    init = assignment();
                    if (init->type == ast::Node::Type::Literal &&
                        init->literal.type == TypeId::Int)
                        folded = clamped_int(static_cast<double>(init->literal.v[0]));
                } else if (constant) {
                    refuse(line, "a const needs an initializer");
                }
                const bool read_only =
                    constant || storage == Storage::Uniform ||
                    storage == Storage::Attribute ||
                    (storage == Storage::Varying && stage_ == Stage::Fragment);
                const auto slot =
                    declare_global(name, *type, array_size, storage, read_only);
                if (constant)
                    scopes_.front()[name].constant = folded;
                if (init) {
                    if (array_size != 0)
                        refuse(line, "array initializers are not supported");
                    ast::GlobalInitializer initializer;
                    initializer.slot = slot;
                    initializer.type = *type;
                    initializer.value = std::move(init);
                    impl_.initializers.push_back(std::move(initializer));
                }
            } while (accept(","));
            expect(";");
        }

        void function(TypeId result)
        {
            const int line = peek().line;
            auto function = std::make_unique<ast::Function>();
            function->name = identifier();
            function->result = result;
            function_name_ = function->name;
            expect("(");
            scopes_.emplace_back();
            frame_size_ = 0;
            if (is_word("void") && is_punct(")", 1)) {
                at_ += 1;
            } else if (!is_punct(")")) {
                do {
                    accept_word("const");
                    ast::Parameter parameter;
                    if (accept_word("in"))
                        parameter.direction = ast::Parameter::Direction::In;
                    else if (accept_word("out"))
                        parameter.direction = ast::Parameter::Direction::Out;
                    else if (accept_word("inout"))
                        parameter.direction = ast::Parameter::Direction::InOut;
                    skip_precision();
                    const auto type = peek_type();
                    if (!type || *type == TypeId::Void)
                        refuse(peek().line, "expected a parameter type");
                    ++at_;
                    parameter.type = *type;
                    if (peek().type == Token::Type::Identifier) {
                        const auto name = identifier();
                        if (is_punct("["))
                            refuse(line, "array parameters are not supported");
                        parameter.slot = declare_local(name, *type, 0).slot;
                    } else {
                        parameter.slot = frame_size_;
                        reserve(1U, line);
                    }
                    function->parameters.push_back(parameter);
                } while (accept(","));
            }
            expect(")");
            auto& overloads = impl_.overloads[function->name];
            ast::Function* target = nullptr;
            for (auto* candidate : overloads) {
                if (candidate->parameters.size() != function->parameters.size())
                    continue;
                bool same = true;
                for (std::size_t i = 0; i < candidate->parameters.size(); ++i)
                    same = same && candidate->parameters[i].type ==
                                       function->parameters[i].type;
                if (same)
                    target = candidate;
            }
            if (target != nullptr && target->result != result)
                refuse(line, "'" + function->name +
                                 "' redeclared with another "
                                 "return type");
            if (target == nullptr) {
                target = function.get();
                overloads.push_back(target);
                impl_.functions.push_back(std::move(function));
            } else {
                // Redeclaration: keep the parameter slots of this declaration
                // for a body that follows it.
                target->parameters = function->parameters;
            }
            if (accept(";")) {
                scopes_.pop_back();
                return;
            }
            if (target->body)
                refuse(line, "'" + target->name + "' is already defined");
            if (target->name == "main" &&
                (!target->parameters.empty() || result != TypeId::Void))
                refuse(line, "main must be void main()");
            current_ = target;
            expect("{");
            target->body = block_rest();
            target->frame_size = frame_size_;
            current_ = nullptr;
            scopes_.pop_back();
            if (target->name == "main")
                impl_.main = target;
        }

        // Statements ---------------------------------------------------------

        std::unique_ptr<ast::Statement> make_statement(
            ast::Statement::Type type, int line)
        {
            auto statement = std::make_unique<ast::Statement>();
            statement->type = type;
            statement->line = line;
            return statement;
        }

        // After the opening brace.
        std::unique_ptr<ast::Statement> block_rest()
        {
            auto block =
                make_statement(ast::Statement::Type::Block, peek().line);
            scopes_.emplace_back();
            while (!is_punct("}")) {
                if (peek().type == Token::Type::End)
                    refuse(peek().line, "unterminated block");
                block->children.push_back(statement());
            }
            ++at_;
            scopes_.pop_back();
            return block;
        }

        bool declaration_ahead() const
        {
            std::size_t ahead = 0;
            if (is_word("const"))
                ++ahead;
            const auto& token = peek(ahead);
            if (token.type == Token::Type::Identifier &&
                precision_word(token.text))
                ++ahead;
            if (peek(ahead).type == Token::Type::Identifier &&
                unsupported_word(peek(ahead).text))
                return true;
            return peek_type(ahead).has_value() &&
                   peek(ahead + 1).type == Token::Type::Identifier;
        }

        std::unique_ptr<ast::Statement> declaration()
        {
            const int line = peek().line;
            const bool constant = accept_word("const");
            skip_precision();
            if (peek().type == Token::Type::Identifier &&
                unsupported_word(peek().text))
                refuse(line, "'" + peek().text + "' is not supported");
            const auto type = peek_type();
            ++at_;
            if (*type == TypeId::Void)
                refuse(line, "a variable cannot be void");
            auto group = make_statement(ast::Statement::Type::Block, line);
            do {
                const auto name = identifier();
                const auto array_size = array_suffix();
                std::unique_ptr<ast::Node> init;
                if (accept("=")) {
                    if (array_size != 0)
                        refuse(line, "array initializers are not supported");
                    init = assignment();
                } else if (constant) {
                    refuse(line, "a const needs an initializer");
                }
                // The initializer is parsed before the name is declared.
                const auto symbol = declare_local(name, *type, array_size);
                if (constant) {
                    scopes_.back()[name].read_only = true;
                    if (init && init->type == ast::Node::Type::Literal &&
                        init->literal.type == TypeId::Int)
                        scopes_.back()[name].constant =
                            clamped_int(static_cast<double>(init->literal.v[0]));
                }
                auto declare =
                    make_statement(ast::Statement::Type::Declare, line);
                declare->declared = *type;
                declare->slot = symbol.slot;
                declare->array_size = array_size;
                declare->expression = std::move(init);
                group->children.push_back(std::move(declare));
            } while (accept(","));
            expect(";");
            return group;
        }

        std::unique_ptr<ast::Statement> statement()
        {
            const int line = peek().line;
            const Nesting nesting { *this, line };
            if (accept("{"))
                return block_rest();
            if (accept(";"))
                return make_statement(ast::Statement::Type::Block, line);
            if (is_word("if")) {
                ++at_;
                auto result = make_statement(ast::Statement::Type::If, line);
                expect("(");
                result->expression = expression();
                expect(")");
                result->children.push_back(scoped_statement());
                if (accept_word("else"))
                    result->children.push_back(scoped_statement());
                return result;
            }
            if (is_word("for")) {
                ++at_;
                auto result = make_statement(ast::Statement::Type::For, line);
                scopes_.emplace_back();
                expect("(");
                if (accept(";")) {
                    result->children.push_back(nullptr);
                } else if (declaration_ahead()) {
                    result->children.push_back(declaration());
                } else {
                    auto init =
                        make_statement(ast::Statement::Type::Expression, line);
                    init->expression = expression();
                    expect(";");
                    result->children.push_back(std::move(init));
                }
                if (!is_punct(";"))
                    result->expression = expression();
                expect(";");
                if (!is_punct(")"))
                    result->step = expression();
                expect(")");
                ++loop_depth_;
                result->children.push_back(scoped_statement());
                --loop_depth_;
                scopes_.pop_back();
                return result;
            }
            if (is_word("while")) {
                ++at_;
                auto result = make_statement(ast::Statement::Type::While, line);
                scopes_.emplace_back();
                expect("(");
                result->expression = expression();
                expect(")");
                ++loop_depth_;
                result->children.push_back(scoped_statement());
                --loop_depth_;
                scopes_.pop_back();
                return result;
            }
            if (is_word("do")) {
                ++at_;
                auto result =
                    make_statement(ast::Statement::Type::DoWhile, line);
                ++loop_depth_;
                result->children.push_back(scoped_statement());
                --loop_depth_;
                if (!accept_word("while"))
                    refuse(peek().line, "expected 'while' after do");
                expect("(");
                result->expression = expression();
                expect(")");
                expect(";");
                return result;
            }
            if (is_word("return")) {
                ++at_;
                auto result =
                    make_statement(ast::Statement::Type::Return, line);
                if (!is_punct(";"))
                    result->expression = expression();
                expect(";");
                return result;
            }
            if (is_word("break") || is_word("continue")) {
                const bool is_break = is_word("break");
                ++at_;
                if (loop_depth_ == 0)
                    refuse(line, "break or continue outside a loop");
                expect(";");
                return make_statement(is_break ? ast::Statement::Type::Break
                                               : ast::Statement::Type::Continue,
                    line);
            }
            if (is_word("discard")) {
                ++at_;
                if (stage_ != Stage::Fragment)
                    refuse(line, "discard outside a fragment shader");
                expect(";");
                return make_statement(ast::Statement::Type::Discard, line);
            }
            if (declaration_ahead())
                return declaration();
            auto result =
                make_statement(ast::Statement::Type::Expression, line);
            result->expression = expression();
            expect(";");
            return result;
        }

        std::unique_ptr<ast::Statement> scoped_statement()
        {
            scopes_.emplace_back();
            auto result = statement();
            scopes_.pop_back();
            return result;
        }

        // Expressions --------------------------------------------------------

        // Gives parent its next argument, keeping the tree within bounds.
        void add_arg(ast::Node& parent, std::unique_ptr<ast::Node> child)
        {
            const auto height = static_cast<unsigned>(child->height) + 1U;
            if (height > maximum_tree_height)
                refuse(parent.line, "the expression is nested too deeply");
            parent.height = std::max<std::uint16_t>(
                parent.height, static_cast<std::uint16_t>(height));
            parent.args.push_back(std::move(child));
        }

        // Counts one level of the parser's recursion for as long as it lives.
        class Nesting {
        public:
            Nesting(Parser& parser, int line)
                : parser_(parser)
            {
                if (++parser_.nesting_ > maximum_parse_nesting) {
                    --parser_.nesting_;
                    refuse(line, "the shader nests statements or "
                                 "expressions too deeply");
                }
            }
            ~Nesting() { --parser_.nesting_; }
            Nesting(const Nesting&) = delete;
            Nesting& operator=(const Nesting&) = delete;

        private:
            Parser& parser_;
        };

        std::unique_ptr<ast::Node> node(ast::Node::Type type, int line)
        {
            auto result = std::make_unique<ast::Node>();
            result->type = type;
            result->line = line;
            return result;
        }

        std::unique_ptr<ast::Node> expression()
        {
            auto result = assignment();
            if (!is_punct(","))
                return result;
            auto sequence = node(ast::Node::Type::Sequence, peek().line);
            add_arg(*sequence, std::move(result));
            while (accept(","))
                add_arg(*sequence, assignment());
            return sequence;
        }

        static const ast::Node* root_of(const ast::Node& target)
        {
            const ast::Node* current = &target;
            while (current->type == ast::Node::Type::Index ||
                   current->type == ast::Node::Type::Swizzle)
                current = current->args[0].get();
            return current;
        }

        void require_writable(const ast::Node& target, int line)
        {
            const auto* root = root_of(target);
            if (root->type != ast::Node::Type::Variable || root->read_only)
                refuse(line, "the target of an assignment is not writable");
        }

        std::unique_ptr<ast::Node> assignment()
        {
            const Nesting nesting { *this, peek().line };
            auto left = conditional();
            const auto& token = peek();
            if (token.type != Token::Type::Punct)
                return left;
            ast::Op op = ast::Op::None;
            if (token.text == "=") {
                op = ast::Op::None;
            } else if (token.text == "+=") {
                op = ast::Op::Add;
            } else if (token.text == "-=") {
                op = ast::Op::Sub;
            } else if (token.text == "*=") {
                op = ast::Op::Mul;
            } else if (token.text == "/=") {
                op = ast::Op::Div;
            } else {
                return left;
            }
            const int line = token.line;
            ++at_;
            require_writable(*left, line);
            auto result = node(ast::Node::Type::Assign, line);
            result->op = op;
            add_arg(*result, std::move(left));
            add_arg(*result, assignment());
            return result;
        }

        std::unique_ptr<ast::Node> conditional()
        {
            auto condition = logical_or();
            if (!is_punct("?"))
                return condition;
            const int line = peek().line;
            ++at_;
            auto result = node(ast::Node::Type::Conditional, line);
            add_arg(*result, std::move(condition));
            add_arg(*result, expression());
            expect(":");
            add_arg(*result, assignment());
            return result;
        }

        std::unique_ptr<ast::Node> binary(ast::Node::Type type, ast::Op op,
            std::unique_ptr<ast::Node> left, std::unique_ptr<ast::Node> right,
            int line)
        {
            auto result = node(type, line);
            result->op = op;
            add_arg(*result, std::move(left));
            add_arg(*result, std::move(right));
            return result;
        }

        std::unique_ptr<ast::Node> logical_or()
        {
            auto left = logical_xor();
            while (is_punct("||")) {
                const int line = peek().line;
                ++at_;
                left = binary(ast::Node::Type::Logical, ast::Op::Or,
                    std::move(left), logical_xor(), line);
            }
            return left;
        }

        std::unique_ptr<ast::Node> logical_xor()
        {
            auto left = logical_and();
            while (is_punct("^^")) {
                const int line = peek().line;
                ++at_;
                left = binary(ast::Node::Type::Binary, ast::Op::Xor,
                    std::move(left), logical_and(), line);
            }
            return left;
        }

        std::unique_ptr<ast::Node> logical_and()
        {
            auto left = equality();
            while (is_punct("&&")) {
                const int line = peek().line;
                ++at_;
                left = binary(ast::Node::Type::Logical, ast::Op::And,
                    std::move(left), equality(), line);
            }
            return left;
        }

        std::unique_ptr<ast::Node> equality()
        {
            auto left = relational();
            while (is_punct("==") || is_punct("!=")) {
                const int line = peek().line;
                const auto op = is_punct("==") ? ast::Op::Eq : ast::Op::Ne;
                ++at_;
                left = binary(ast::Node::Type::Binary, op, std::move(left),
                    relational(), line);
            }
            return left;
        }

        std::unique_ptr<ast::Node> relational()
        {
            auto left = additive();
            for (;;) {
                ast::Op op;
                if (is_punct("<"))
                    op = ast::Op::Lt;
                else if (is_punct(">"))
                    op = ast::Op::Gt;
                else if (is_punct("<="))
                    op = ast::Op::Le;
                else if (is_punct(">="))
                    op = ast::Op::Ge;
                else
                    return left;
                const int line = peek().line;
                ++at_;
                left = binary(ast::Node::Type::Binary, op, std::move(left),
                    additive(), line);
            }
        }

        std::unique_ptr<ast::Node> additive()
        {
            auto left = multiplicative();
            while (is_punct("+") || is_punct("-")) {
                const int line = peek().line;
                const auto op = is_punct("+") ? ast::Op::Add : ast::Op::Sub;
                ++at_;
                left = binary(ast::Node::Type::Binary, op, std::move(left),
                    multiplicative(), line);
            }
            return left;
        }

        std::unique_ptr<ast::Node> multiplicative()
        {
            auto left = unary();
            while (is_punct("*") || is_punct("/")) {
                const int line = peek().line;
                const auto op = is_punct("*") ? ast::Op::Mul : ast::Op::Div;
                ++at_;
                left = binary(ast::Node::Type::Binary, op, std::move(left),
                    unary(), line);
            }
            return left;
        }

        std::unique_ptr<ast::Node> unary()
        {
            const int line = peek().line;
            if (is_punct("-") || is_punct("+") || is_punct("!")) {
                const Nesting nesting { *this, line };
                const auto op = is_punct("-") ? ast::Op::Neg
                                              : (is_punct("+") ? ast::Op::Plus
                                                               : ast::Op::Not);
                ++at_;
                auto result = node(ast::Node::Type::Unary, line);
                result->op = op;
                add_arg(*result, unary());
                return result;
            }
            if (is_punct("++") || is_punct("--")) {
                const Nesting nesting { *this, line };
                const auto op = is_punct("++") ? ast::Op::Add : ast::Op::Sub;
                ++at_;
                auto result = node(ast::Node::Type::Increment, line);
                result->op = op;
                result->prefix = true;
                add_arg(*result, unary());
                require_writable(*result->args[0], line);
                return result;
            }
            return postfix();
        }

        static std::optional<std::uint8_t> swizzle_index(char c, int& family)
        {
            static constexpr std::string_view sets[] = { "xyzw", "rgba",
                "stpq" };
            for (int set = 0; set < 3; ++set) {
                const auto found = sets[set].find(c);
                if (found == std::string_view::npos)
                    continue;
                if (family >= 0 && family != set)
                    return std::nullopt;
                family = set;
                return static_cast<std::uint8_t>(found);
            }
            return std::nullopt;
        }

        std::unique_ptr<ast::Node> postfix()
        {
            auto result = primary();
            for (;;) {
                const int line = peek().line;
                if (accept("[")) {
                    auto index = node(ast::Node::Type::Index, line);
                    index->array_index =
                        result->type == ast::Node::Type::Variable &&
                        result->array_size != 0;
                    add_arg(*index, std::move(result));
                    add_arg(*index, expression());
                    expect("]");
                    result = std::move(index);
                } else if (accept(".")) {
                    const auto field = identifier();
                    if (field.size() > 4)
                        refuse(line, "'" + field + "' is not a swizzle");
                    auto swizzle = node(ast::Node::Type::Swizzle, line);
                    int family = -1;
                    for (const char c : field) {
                        const auto index = swizzle_index(c, family);
                        if (!index)
                            refuse(line, "'" + field + "' is not a swizzle");
                        swizzle->swizzle[swizzle->swizzle_count++] = *index;
                    }
                    add_arg(*swizzle, std::move(result));
                    result = std::move(swizzle);
                } else if (is_punct("++") || is_punct("--")) {
                    const auto op =
                        is_punct("++") ? ast::Op::Add : ast::Op::Sub;
                    ++at_;
                    auto step = node(ast::Node::Type::Increment, line);
                    step->op = op;
                    add_arg(*step, std::move(result));
                    require_writable(*step->args[0], line);
                    result = std::move(step);
                } else {
                    return result;
                }
            }
        }

        std::unique_ptr<ast::Node> primary()
        {
            const auto token = peek();
            const int line = token.line;
            if (token.type == Token::Type::Integer) {
                ++at_;
                auto result = node(ast::Node::Type::Literal, line);
                result->literal = ast::make(TypeId::Int);
                result->literal.v[0] =
                    static_cast<float>(clamped_int(token.number));
                return result;
            }
            if (token.type == Token::Type::Number) {
                ++at_;
                auto result = node(ast::Node::Type::Literal, line);
                result->literal =
                    ast::make_float(static_cast<float>(token.number));
                return result;
            }
            if (accept("(")) {
                auto result = expression();
                expect(")");
                return result;
            }
            if (token.type != Token::Type::Identifier)
                refuse(line, "unexpected '" + token.text + "'");
            if (token.text == "true" || token.text == "false") {
                ++at_;
                auto result = node(ast::Node::Type::Literal, line);
                result->literal = ast::make_bool(token.text == "true");
                return result;
            }
            if (unsupported_word(token.text))
                refuse(line, "'" + token.text + "' is not supported");
            if (is_punct("(", 1)) {
                ++at_;
                return call(token.text, line);
            }
            ++at_;
            const auto* symbol = lookup(token.text);
            if (symbol == nullptr)
                refuse(line, "'" + token.text + "' is not declared");
            auto result = node(ast::Node::Type::Variable, line);
            result->name = token.text;
            result->global = symbol->global;
            result->slot = symbol->slot;
            result->array_size = symbol->array_size;
            result->read_only = symbol->read_only;
            return result;
        }

        std::unique_ptr<ast::Node> call(const std::string& name, int line)
        {
            std::unique_ptr<ast::Node> result;
            const auto type = type_from_name(name);
            const auto overloads = impl_.overloads.find(name);
            if (type) {
                if (*type == TypeId::Void || *type == TypeId::Sampler2D)
                    refuse(line, "'" + name + "' is not a constructor");
                result = node(ast::Node::Type::Construct, line);
                result->construct = *type;
            } else if (overloads != impl_.overloads.end()) {
                result = node(ast::Node::Type::Call, line);
                result->overloads = &overloads->second;
            } else if (const auto found = ast::builtin_names().find(name);
                found != ast::builtin_names().end()) {
                result = node(ast::Node::Type::Builtin, line);
                result->builtin = found->second;
            } else {
                refuse(line, "no function named '" + name + "'");
            }
            result->name = name;
            expect("(");
            if (!is_punct(")")) {
                if (is_word("void") && is_punct(")", 1)) {
                    ++at_;
                } else {
                    do {
                        add_arg(*result, assignment());
                    } while (accept(","));
                }
            }
            expect(")");
            if (result->args.size() > 16)
                refuse(line, "too many arguments");
            return result;
        }

        std::vector<Token> tokens_;
        std::size_t at_ { };
        Stage stage_;
        Module::Impl& impl_;
        std::vector<std::map<std::string, Symbol>> scopes_;
        std::uint32_t frame_size_ { };
        std::string function_name_;
        ast::Function* current_ { };
        int loop_depth_ { };
        int nesting_ { };
    };

    struct RunError {
        int line { };
        std::string message;
    };

    [[noreturn]] void fail(int line, std::string message)
    {
        throw RunError { line, std::move(message) };
    }

    constexpr std::uint32_t maximum_depth = 32;

    // A reference to components of a stored value, for assignment.
    struct Reference {
        Value* base { };
        std::array<std::uint8_t, 16> components { };
        std::uint8_t count { };
        TypeId type { TypeId::Void };
    };

    enum class Flow : std::uint8_t { Normal, Break, Continue, Return, Discard };

    float truncate_toward_zero(float x) { return std::trunc(x); }

} // namespace

struct Instance::State {
    explicit State(const Module::Impl& module)
        : impl(&module)
        , globals(module.initial_globals)
        , stack(stack_values)
    {
    }

    const Module::Impl* impl;
    std::vector<Value> globals;
    std::vector<Value> stack;
    const TextureAccess* textures { };
    std::uint64_t steps { };
    // What the run may take: the invocation's share, or what is left of the
    // draw's.
    std::uint64_t step_limit { maximum_steps };
    std::uint32_t base { };
    std::uint32_t top { };
    std::uint32_t depth { };
    // The evaluations and statements now being executed, calls included.
    std::uint32_t nesting { };
    Value returned;

    // One level of the run's recursion, counted for as long as it lives (an
    // exception that leaves the run unwinds the count with it).
    class Nest {
    public:
        Nest(State& state, int line)
            : state_(state)
        {
            if (state_.nesting >= maximum_run_nesting)
                fail(line, "the shader nests too deeply");
            ++state_.nesting;
        }
        ~Nest() { --state_.nesting; }
        Nest(const Nest&) = delete;
        Nest& operator=(const Nest&) = delete;

    private:
        State& state_;
    };

    Value* slot_of(const ast::Node& variable)
    {
        return variable.global ? &globals[variable.slot]
                               : &stack[base + variable.slot];
    }

    void tick(int line)
    {
        if (++steps > step_limit)
            fail(line, step_limit < maximum_steps ? "the draw ran too long"
                                                  : "the shader ran too long");
    }

    // Values -------------------------------------------------------------

    static Value read(const Reference& reference)
    {
        Value result = ast::make(reference.type);
        for (int i = 0; i < reference.count; ++i)
            result.v[static_cast<std::size_t>(i)] =
                reference.base
                    ->v[reference.components[static_cast<std::size_t>(i)]];
        return result;
    }

    static void write(const Reference& reference, const Value& value, int line)
    {
        if (value.type != reference.type)
            fail(line, std::string { "cannot assign " } +
                           std::string { type_name(value.type) } + " to " +
                           std::string { type_name(reference.type) });
        for (int i = 0; i < reference.count; ++i)
            reference.base
                ->v[reference.components[static_cast<std::size_t>(i)]] =
                value.v[static_cast<std::size_t>(i)];
    }

    int index_of(const ast::Node& expression, int limit)
    {
        const auto value = eval(expression);
        if (value.type != TypeId::Int)
            fail(expression.line, "an index must be an int");
        const auto index = clamped_int(static_cast<double>(value.v[0]));
        if (index < 0 || index >= limit)
            fail(expression.line, "index out of range");
        return index;
    }

    Reference lvalue(const ast::Node& target)
    {
        Reference result;
        switch (target.type) {
        case ast::Node::Type::Variable: {
            if (target.array_size != 0)
                fail(target.line, "an array needs an index");
            result.base = slot_of(target);
            break;
        }
        case ast::Node::Type::Index: {
            if (target.array_index) {
                const auto& array = *target.args[0];
                const auto index = index_of(
                    *target.args[1], static_cast<int>(array.array_size));
                result.base = slot_of(array) + index;
                break;
            }
            const auto inner = lvalue(*target.args[0]);
            const auto type = inner.type;
            if (!ast::is_vector_or_scalar(type) && !ast::is_matrix(type))
                fail(target.line, "this value cannot be indexed");
            if (ast::is_matrix(type)) {
                const int order = ast::dimension(type);
                const auto index = index_of(*target.args[1], order);
                result.base = inner.base;
                result.type = ast::vector_of(ast::Kind::Float, order);
                result.count = static_cast<std::uint8_t>(order);
                for (int row = 0; row < order; ++row)
                    result.components[static_cast<std::size_t>(row)] =
                        inner.components[static_cast<std::size_t>(
                            index * order + row)];
                return result;
            }
            if (inner.count == 1)
                fail(target.line, "a scalar cannot be indexed");
            const auto index = index_of(*target.args[1], inner.count);
            result.base = inner.base;
            result.type = ast::vector_of(ast::kind_of(type), 1);
            result.count = 1;
            result.components[0] =
                inner.components[static_cast<std::size_t>(index)];
            return result;
        }
        case ast::Node::Type::Swizzle: {
            const auto inner = lvalue(*target.args[0]);
            if (!ast::is_vector_or_scalar(inner.type) || inner.count < 2)
                fail(target.line, "only a vector can be swizzled");
            result.base = inner.base;
            result.type =
                ast::vector_of(ast::kind_of(inner.type), target.swizzle_count);
            result.count = target.swizzle_count;
            for (int i = 0; i < target.swizzle_count; ++i) {
                const auto component =
                    target.swizzle[static_cast<std::size_t>(i)];
                if (component >= inner.count)
                    fail(target.line, "swizzle component out of range");
                result.components[static_cast<std::size_t>(i)] =
                    inner.components[component];
            }
            return result;
        }
        default:
            fail(target.line, "not an l-value");
        }
        result.type = result.base->type;
        result.count = static_cast<std::uint8_t>(ast::count_of(result.type));
        for (int i = 0; i < result.count; ++i)
            result.components[static_cast<std::size_t>(i)] =
                static_cast<std::uint8_t>(i);
        return result;
    }

    // Operators ----------------------------------------------------------

    static Value arithmetic(
        ast::Op op, const Value& a, const Value& b, int line)
    {
        const bool a_matrix = ast::is_matrix(a.type);
        const bool b_matrix = ast::is_matrix(b.type);
        if (op == ast::Op::Mul && (a_matrix || b_matrix)) {
            if (a_matrix && b_matrix) {
                if (a.type != b.type)
                    fail(line, "matrix sizes differ");
                const int n = ast::dimension(a.type);
                Value r = ast::make(a.type);
                for (int col = 0; col < n; ++col)
                    for (int row = 0; row < n; ++row) {
                        float sum = 0.0F;
                        for (int k = 0; k < n; ++k)
                            sum += a.v[static_cast<std::size_t>(k * n + row)] *
                                   b.v[static_cast<std::size_t>(col * n + k)];
                        r.v[static_cast<std::size_t>(col * n + row)] = sum;
                    }
                return r;
            }
            if (a_matrix && b.type == ast::vector_of(ast::Kind::Float,
                                          ast::dimension(a.type))) {
                const int n = ast::dimension(a.type);
                Value r = ast::make(b.type);
                for (int row = 0; row < n; ++row) {
                    float sum = 0.0F;
                    for (int col = 0; col < n; ++col)
                        sum += a.v[static_cast<std::size_t>(col * n + row)] *
                               b.v[static_cast<std::size_t>(col)];
                    r.v[static_cast<std::size_t>(row)] = sum;
                }
                return r;
            }
            if (b_matrix && a.type == ast::vector_of(ast::Kind::Float,
                                          ast::dimension(b.type))) {
                const int n = ast::dimension(b.type);
                Value r = ast::make(a.type);
                for (int col = 0; col < n; ++col) {
                    float sum = 0.0F;
                    for (int row = 0; row < n; ++row)
                        sum += a.v[static_cast<std::size_t>(row)] *
                               b.v[static_cast<std::size_t>(col * n + row)];
                    r.v[static_cast<std::size_t>(col)] = sum;
                }
                return r;
            }
            // A matrix times a scalar falls through to the component-wise
            // case below.
        }
        const int na = ast::count_of(a.type);
        const int nb = ast::count_of(b.type);
        const bool a_numeric = a.type != TypeId::Void &&
                               a.type != TypeId::Sampler2D &&
                               ast::kind_of(a.type) != ast::Kind::Bool;
        const bool b_numeric = b.type != TypeId::Void &&
                               b.type != TypeId::Sampler2D &&
                               ast::kind_of(b.type) != ast::Kind::Bool;
        if (!a_numeric || !b_numeric)
            fail(line, "arithmetic on a non-numeric operand");
        if (ast::kind_of(a.type) != ast::kind_of(b.type))
            fail(line, std::string { "operands " } +
                           std::string { type_name(a.type) } + " and " +
                           std::string { type_name(b.type) } +
                           " mix int and float");
        if (na != nb && na != 1 && nb != 1)
            fail(line, "operand sizes differ");
        if (na == nb && a.type != b.type)
            fail(line, "operand types differ");
        const auto type = na >= nb ? a.type : b.type;
        const bool integral = ast::kind_of(type) == ast::Kind::Int;
        Value r = ast::make(type);
        const int n = std::max(na, nb);
        for (int i = 0; i < n; ++i) {
            const float x = a.v[static_cast<std::size_t>(na == 1 ? 0 : i)];
            const float y = b.v[static_cast<std::size_t>(nb == 1 ? 0 : i)];
            float z = 0.0F;
            switch (op) {
            case ast::Op::Add:
                z = x + y;
                break;
            case ast::Op::Sub:
                z = x - y;
                break;
            case ast::Op::Mul:
                z = x * y;
                break;
            case ast::Op::Div:
                if (integral)
                    z = y == 0.0F ? 0.0F : truncate_toward_zero(x / y);
                else
                    z = x / y;
                break;
            default:
                break;
            }
            r.v[static_cast<std::size_t>(i)] = z;
        }
        return r;
    }

    static Value binary(ast::Op op, const Value& a, const Value& b, int line)
    {
        switch (op) {
        case ast::Op::Add:
        case ast::Op::Sub:
        case ast::Op::Mul:
        case ast::Op::Div:
            return arithmetic(op, a, b, line);
        case ast::Op::Lt:
        case ast::Op::Gt:
        case ast::Op::Le:
        case ast::Op::Ge: {
            if (a.type != b.type ||
                (a.type != TypeId::Float && a.type != TypeId::Int))
                fail(line, "comparison needs two floats or two ints");
            const float x = a.v[0];
            const float y = b.v[0];
            switch (op) {
            case ast::Op::Lt:
                return ast::make_bool(x < y);
            case ast::Op::Gt:
                return ast::make_bool(x > y);
            case ast::Op::Le:
                return ast::make_bool(x <= y);
            default:
                return ast::make_bool(x >= y);
            }
        }
        case ast::Op::Eq:
        case ast::Op::Ne: {
            if (a.type != b.type || a.type == TypeId::Void)
                fail(line, "== needs two operands of one type");
            bool equal = true;
            for (int i = 0; i < ast::count_of(a.type); ++i)
                equal = equal && a.v[static_cast<std::size_t>(i)] ==
                                     b.v[static_cast<std::size_t>(i)];
            return ast::make_bool(op == ast::Op::Eq ? equal : !equal);
        }
        case ast::Op::Xor:
            if (a.type != TypeId::Bool || b.type != TypeId::Bool)
                fail(line, "^^ needs bools");
            return ast::make_bool((a.v[0] != 0.0F) != (b.v[0] != 0.0F));
        default:
            fail(line, "unsupported operator");
        }
    }

    // Built-in functions -------------------------------------------------

    template <class F>
    static Value componentwise(const Value* args, int argc, F function)
    {
        const Value* widest = &args[0];
        for (int i = 1; i < argc; ++i)
            if (ast::count_of(args[i].type) > ast::count_of(widest->type))
                widest = &args[i];
        Value result = ast::make(widest->type);
        const int n = ast::count_of(widest->type);
        for (int i = 0; i < n; ++i) {
            float x[3] { };
            for (int k = 0; k < argc && k < 3; ++k) {
                const auto& arg = args[k];
                x[k] = arg.v[static_cast<std::size_t>(
                    ast::count_of(arg.type) == 1 ? 0 : i)];
            }
            result.v[static_cast<std::size_t>(i)] = function(x);
        }
        return result;
    }

    static void require_float_genus(const Value* args, int argc, int line)
    {
        for (int i = 0; i < argc; ++i)
            if (!ast::is_vector_or_scalar(args[i].type) ||
                ast::kind_of(args[i].type) != ast::Kind::Float)
                fail(line, "a built-in function needs float arguments");
    }

    Value texture(const Value* args, int argc, bool project, int line)
    {
        if (argc < 2 || args[0].type != TypeId::Sampler2D)
            fail(line, "texture2D needs a sampler and a coordinate");
        float s = 0.0F;
        float t = 0.0F;
        const auto& c = args[1];
        if (project) {
            if (c.type != TypeId::Vec3 && c.type != TypeId::Vec4)
                fail(line, "texture2DProj needs a vec3 or vec4");
            const float q = c.type == TypeId::Vec3 ? c.v[2] : c.v[3];
            s = c.v[0] / q;
            t = c.v[1] / q;
        } else {
            if (c.type != TypeId::Vec2)
                fail(line, "texture2D needs a vec2 coordinate");
            s = c.v[0];
            t = c.v[1];
        }
        Value result = ast::make(TypeId::Vec4);
        if (textures == nullptr) {
            result.v[3] = 1.0F;
            return result;
        }
        const auto color =
            textures->sample(static_cast<std::uint32_t>(std::max(
                                 clamped_int(static_cast<double>(args[0].v[0])),
                                 0)),
                s, t);
        for (std::size_t i = 0; i < 4; ++i)
            result.v[i] = color[i];
        return result;
    }

    Value builtin(ast::Builtin function, const Value* args, int argc, int line)
    {
        using B = ast::Builtin;
        auto need = [&](int count) {
            if (argc != count)
                fail(line, "wrong number of arguments");
        };
        auto unary_float = [&](auto f) {
            need(1);
            require_float_genus(args, 1, line);
            return componentwise(
                args, 1, [&](const float* x) { return f(x[0]); });
        };
        switch (function) {
        case B::Radians:
            return unary_float(
                [](float x) { return x * 0.017453292519943295F; });
        case B::Degrees:
            return unary_float([](float x) { return x * 57.29577951308232F; });
        case B::Sin:
            return unary_float([](float x) { return std::sin(x); });
        case B::Cos:
            return unary_float([](float x) { return std::cos(x); });
        case B::Tan:
            return unary_float([](float x) { return std::tan(x); });
        case B::Asin:
            return unary_float([](float x) { return std::asin(x); });
        case B::Acos:
            return unary_float([](float x) { return std::acos(x); });
        case B::Atan:
            if (argc == 2) {
                require_float_genus(args, 2, line);
                return componentwise(args, 2,
                    [](const float* x) { return std::atan2(x[0], x[1]); });
            }
            return unary_float([](float x) { return std::atan(x); });
        case B::Exp:
            return unary_float([](float x) { return std::exp(x); });
        case B::Log:
            return unary_float([](float x) { return std::log(x); });
        case B::Exp2:
            return unary_float([](float x) { return std::exp2(x); });
        case B::Log2:
            return unary_float([](float x) { return std::log2(x); });
        case B::Sqrt:
            return unary_float([](float x) { return std::sqrt(x); });
        case B::Inversesqrt:
            return unary_float([](float x) { return 1.0F / std::sqrt(x); });
        case B::Abs:
            return unary_float([](float x) { return std::fabs(x); });
        case B::Sign:
            return unary_float([](float x) {
                return x > 0.0F ? 1.0F : (x < 0.0F ? -1.0F : 0.0F);
            });
        case B::Floor:
            return unary_float([](float x) { return std::floor(x); });
        case B::Ceil:
            return unary_float([](float x) { return std::ceil(x); });
        case B::Fract:
            return unary_float([](float x) { return x - std::floor(x); });
        case B::Pow:
            need(2);
            require_float_genus(args, 2, line);
            return componentwise(
                args, 2, [](const float* x) { return std::pow(x[0], x[1]); });
        case B::Mod:
            need(2);
            require_float_genus(args, 2, line);
            return componentwise(args, 2, [](const float* x) {
                return x[0] - x[1] * std::floor(x[0] / x[1]);
            });
        case B::Min:
            need(2);
            require_float_genus(args, 2, line);
            return componentwise(
                args, 2, [](const float* x) { return std::min(x[0], x[1]); });
        case B::Max:
            need(2);
            require_float_genus(args, 2, line);
            return componentwise(
                args, 2, [](const float* x) { return std::max(x[0], x[1]); });
        case B::Clamp:
            need(3);
            require_float_genus(args, 3, line);
            return componentwise(args, 3, [](const float* x) {
                return std::min(std::max(x[0], x[1]), x[2]);
            });
        case B::Mix:
            need(3);
            require_float_genus(args, 3, line);
            // mix(x, y, a): the widest argument may be a, so order the
            // operands by hand.
            {
                Value result = ast::make(args[0].type);
                const int n = ast::count_of(args[0].type);
                const int na = ast::count_of(args[2].type);
                for (int i = 0; i < n; ++i) {
                    const float a =
                        args[2].v[static_cast<std::size_t>(na == 1 ? 0 : i)];
                    result.v[static_cast<std::size_t>(i)] =
                        args[0].v[static_cast<std::size_t>(i)] * (1.0F - a) +
                        args[1].v[static_cast<std::size_t>(i)] * a;
                }
                return result;
            }
        case B::Step:
            need(2);
            require_float_genus(args, 2, line);
            return componentwise(args, 2,
                [](const float* x) { return x[1] < x[0] ? 0.0F : 1.0F; });
        case B::Smoothstep:
            need(3);
            require_float_genus(args, 3, line);
            {
                // Edges first: the value is the last argument.
                Value result = ast::make(args[2].type);
                const int n = ast::count_of(args[2].type);
                const int n0 = ast::count_of(args[0].type);
                const int n1 = ast::count_of(args[1].type);
                for (int i = 0; i < n; ++i) {
                    const float e0 =
                        args[0].v[static_cast<std::size_t>(n0 == 1 ? 0 : i)];
                    const float e1 =
                        args[1].v[static_cast<std::size_t>(n1 == 1 ? 0 : i)];
                    const float t = std::min(
                        std::max((args[2].v[static_cast<std::size_t>(i)] - e0) /
                                     (e1 - e0),
                            0.0F),
                        1.0F);
                    result.v[static_cast<std::size_t>(i)] =
                        t * t * (3.0F - 2.0F * t);
                }
                return result;
            }
        case B::Length:
        case B::Distance:
        case B::Dot: {
            const bool two = function != B::Length;
            need(two ? 2 : 1);
            require_float_genus(args, two ? 2 : 1, line);
            if (two && args[0].type != args[1].type)
                fail(line, "argument types differ");
            float sum = 0.0F;
            for (int i = 0; i < ast::count_of(args[0].type); ++i) {
                const auto k = static_cast<std::size_t>(i);
                float x = args[0].v[k];
                if (function == B::Length)
                    sum += x * x;
                else if (function == B::Distance)
                    sum += (x - args[1].v[k]) * (x - args[1].v[k]);
                else
                    sum += x * args[1].v[k];
            }
            return ast::make_float(function == B::Dot ? sum : std::sqrt(sum));
        }
        case B::Cross: {
            need(2);
            if (args[0].type != TypeId::Vec3 || args[1].type != TypeId::Vec3)
                fail(line, "cross needs two vec3");
            Value r = ast::make(TypeId::Vec3);
            const auto& a = args[0].v;
            const auto& b = args[1].v;
            r.v[0] = a[1] * b[2] - a[2] * b[1];
            r.v[1] = a[2] * b[0] - a[0] * b[2];
            r.v[2] = a[0] * b[1] - a[1] * b[0];
            return r;
        }
        case B::Normalize: {
            need(1);
            require_float_genus(args, 1, line);
            Value r = args[0];
            float sum = 0.0F;
            const int n = ast::count_of(r.type);
            for (int i = 0; i < n; ++i)
                sum += r.v[static_cast<std::size_t>(i)] *
                       r.v[static_cast<std::size_t>(i)];
            const float length = std::sqrt(sum);
            for (int i = 0; i < n; ++i)
                r.v[static_cast<std::size_t>(i)] /= length;
            return r;
        }
        case B::Faceforward:
        case B::Reflect:
        case B::Refract: {
            const bool three = function != B::Reflect;
            need(three ? 3 : 2);
            if (function == B::Refract) {
                require_float_genus(args, 2, line);
                if (args[2].type != TypeId::Float)
                    fail(line, "refract needs a float eta");
            } else {
                require_float_genus(args, three ? 3 : 2, line);
            }
            const int n = ast::count_of(args[0].type);
            auto dot = [&](const Value& a, const Value& b) {
                float sum = 0.0F;
                for (int i = 0; i < n; ++i)
                    sum += a.v[static_cast<std::size_t>(i)] *
                           b.v[static_cast<std::size_t>(i)];
                return sum;
            };
            Value r = args[0];
            if (function == B::Faceforward) {
                if (dot(args[2], args[1]) >= 0.0F)
                    for (int i = 0; i < n; ++i)
                        r.v[static_cast<std::size_t>(i)] =
                            -r.v[static_cast<std::size_t>(i)];
                return r;
            }
            const float d = dot(args[1], args[0]);
            if (function == B::Reflect) {
                for (int i = 0; i < n; ++i) {
                    const auto k = static_cast<std::size_t>(i);
                    r.v[k] = args[0].v[k] - 2.0F * d * args[1].v[k];
                }
                return r;
            }
            const float eta = args[2].v[0];
            const float k = 1.0F - eta * eta * (1.0F - d * d);
            for (int i = 0; i < n; ++i) {
                const auto j = static_cast<std::size_t>(i);
                r.v[j] = k < 0.0F ? 0.0F
                                  : eta * args[0].v[j] -
                                        (eta * d + std::sqrt(k)) * args[1].v[j];
            }
            return r;
        }
        case B::MatrixCompMult: {
            need(2);
            if (!ast::is_matrix(args[0].type) || args[0].type != args[1].type)
                fail(line, "matrixCompMult needs two matrices of one size");
            Value r = args[0];
            for (int i = 0; i < ast::count_of(r.type); ++i)
                r.v[static_cast<std::size_t>(i)] *=
                    args[1].v[static_cast<std::size_t>(i)];
            return r;
        }
        case B::LessThan:
        case B::LessThanEqual:
        case B::GreaterThan:
        case B::GreaterThanEqual:
        case B::Equal:
        case B::NotEqual: {
            need(2);
            const auto type = args[0].type;
            if (type != args[1].type || !ast::is_vector_or_scalar(type) ||
                ast::count_of(type) < 2)
                fail(line, "a comparison function needs two vectors");
            Value r =
                ast::make(ast::vector_of(ast::Kind::Bool, ast::count_of(type)));
            for (int i = 0; i < ast::count_of(type); ++i) {
                const auto k = static_cast<std::size_t>(i);
                const float x = args[0].v[k];
                const float y = args[1].v[k];
                bool result = false;
                switch (function) {
                case B::LessThan:
                    result = x < y;
                    break;
                case B::LessThanEqual:
                    result = x <= y;
                    break;
                case B::GreaterThan:
                    result = x > y;
                    break;
                case B::GreaterThanEqual:
                    result = x >= y;
                    break;
                case B::Equal:
                    result = x == y;
                    break;
                default:
                    result = x != y;
                    break;
                }
                r.v[k] = result ? 1.0F : 0.0F;
            }
            return r;
        }
        case B::Any:
        case B::All: {
            need(1);
            const auto type = args[0].type;
            if (!ast::is_vector_or_scalar(type) ||
                ast::kind_of(type) != ast::Kind::Bool ||
                ast::count_of(type) < 2)
                fail(line, "any and all need a bvec");
            bool any = false;
            bool all = true;
            for (int i = 0; i < ast::count_of(type); ++i) {
                const bool bit = args[0].v[static_cast<std::size_t>(i)] != 0.0F;
                any = any || bit;
                all = all && bit;
            }
            return ast::make_bool(function == B::Any ? any : all);
        }
        case B::Not: {
            need(1);
            const auto type = args[0].type;
            if (!ast::is_vector_or_scalar(type) ||
                ast::kind_of(type) != ast::Kind::Bool ||
                ast::count_of(type) < 2)
                fail(line, "not needs a bvec");
            Value r = args[0];
            for (int i = 0; i < ast::count_of(type); ++i)
                r.v[static_cast<std::size_t>(i)] =
                    args[0].v[static_cast<std::size_t>(i)] != 0.0F ? 0.0F
                                                                   : 1.0F;
            return r;
        }
        case B::Texture2D:
        case B::Texture2DLod:
            return texture(args, argc, false, line);
        case B::Texture2DProj:
        case B::Texture2DProjLod:
            return texture(args, argc, true, line);
        }
        fail(line, "unsupported built-in");
    }

    // Constructors -------------------------------------------------------

    static Value construct(TypeId type, const Value* args, int argc, int line)
    {
        if (argc < 1)
            fail(line, "a constructor needs arguments");
        std::array<float, 32> parts { };
        int total = 0;
        for (int i = 0; i < argc; ++i) {
            if (args[i].type == TypeId::Void ||
                args[i].type == TypeId::Sampler2D)
                fail(line, "this argument cannot be converted");
            for (int k = 0; k < ast::count_of(args[i].type); ++k) {
                if (total >= 32)
                    fail(line, "too many constructor components");
                parts[static_cast<std::size_t>(total++)] =
                    args[i].v[static_cast<std::size_t>(k)];
            }
        }
        const auto kind = ast::kind_of(type);
        auto convert = [&](float x) {
            switch (kind) {
            case ast::Kind::Bool:
                return x != 0.0F ? 1.0F : 0.0F;
            case ast::Kind::Int:
                return truncate_toward_zero(x);
            default:
                return x;
            }
        };
        Value result = ast::make(type);
        const int n = ast::count_of(type);
        if (ast::is_matrix(type)) {
            const int order = ast::dimension(type);
            if (total == 1) {
                for (int i = 0; i < order; ++i)
                    result.v[static_cast<std::size_t>(i * order + i)] =
                        parts[0];
                return result;
            }
            if (total < n)
                fail(line, "too few matrix components");
            if (argc == 1 && ast::is_matrix(args[0].type))
                fail(line, "a matrix cannot be built from a matrix");
            for (int i = 0; i < n; ++i)
                result.v[static_cast<std::size_t>(i)] =
                    parts[static_cast<std::size_t>(i)];
            return result;
        }
        if (total == 1) {
            for (int i = 0; i < n; ++i)
                result.v[static_cast<std::size_t>(i)] = convert(parts[0]);
            return result;
        }
        if (total < n)
            fail(line, "too few constructor components");
        for (int i = 0; i < n; ++i)
            result.v[static_cast<std::size_t>(i)] =
                convert(parts[static_cast<std::size_t>(i)]);
        return result;
    }

    // Calls --------------------------------------------------------------

    // Evaluated arguments live on the stack above the frame in use, so a call
    // allocates nothing.
    class Arguments {
    public:
        Arguments(State& state, std::size_t count, int line)
            : state_(state)
            , count_(static_cast<std::uint32_t>(count))
        {
            if (state.top + count_ > stack_values)
                fail(line, "the shader's stack is full");
            data_ = state.stack.data() + state.top;
            state.top += count_;
        }
        ~Arguments() { state_.top -= count_; }
        Arguments(const Arguments&) = delete;
        Arguments& operator=(const Arguments&) = delete;

        Value& operator[](std::size_t index) { return data_[index]; }
        Value* data() { return data_; }

    private:
        State& state_;
        std::uint32_t count_ { };
        Value* data_ { };
    };

    Value call(const ast::Node& node)
    {
        const auto argc = node.args.size();
        Arguments args { *this, argc, node.line };
        for (std::size_t i = 0; i < argc; ++i)
            args[i] = eval(*node.args[i]);
        const ast::Function* chosen = nullptr;
        for (const auto* candidate : *node.overloads) {
            if (candidate->parameters.size() != argc || !candidate->body)
                continue;
            bool match = true;
            for (std::size_t i = 0; i < argc; ++i)
                match = match && candidate->parameters[i].type == args[i].type;
            if (match) {
                chosen = candidate;
                break;
            }
        }
        if (chosen == nullptr)
            fail(node.line,
                "no overload of '" + node.name + "' matches these arguments");
        if (depth >= maximum_depth)
            fail(node.line, "calls nest too deeply");
        tick(node.line);
        std::array<Reference, 16> targets { };
        for (std::size_t i = 0; i < argc; ++i)
            if (chosen->parameters[i].direction !=
                ast::Parameter::Direction::In)
                targets[i] = lvalue(*node.args[i]);
        const auto new_base = top;
        if (new_base + chosen->frame_size > stack_values)
            fail(node.line, "the shader's stack is full");
        for (std::size_t i = 0; i < argc; ++i) {
            const auto& parameter = chosen->parameters[i];
            stack[new_base + parameter.slot] =
                parameter.direction == ast::Parameter::Direction::Out
                    ? ast::make(parameter.type)
                    : args[i];
        }
        const auto saved_base = base;
        const auto saved_top = top;
        base = new_base;
        top = new_base + chosen->frame_size;
        ++depth;
        returned = ast::make(TypeId::Void);
        const auto flow = exec(*chosen->body);
        --depth;
        Value result = returned;
        base = saved_base;
        top = saved_top;
        if (flow == Flow::Discard) {
            returned = ast::make(TypeId::Void);
            throw Discarded { };
        }
        if (result.type != chosen->result)
            fail(node.line, "'" + node.name + "' returned " +
                                std::string { type_name(result.type) } +
                                ", not " +
                                std::string { type_name(chosen->result) });
        // The callee's frame is still intact above the stack top.
        for (std::size_t i = 0; i < argc; ++i)
            if (chosen->parameters[i].direction !=
                ast::Parameter::Direction::In)
                write(targets[i], stack[new_base + chosen->parameters[i].slot],
                    node.line);
        return result;
    }

    struct Discarded { };

    // Expressions --------------------------------------------------------

    Value eval(const ast::Node& node)
    {
        const Nest nest { *this, node.line };
        using T = ast::Node::Type;
        switch (node.type) {
        case T::Literal:
            return node.literal;
        case T::Variable:
            if (node.array_size != 0)
                fail(node.line, "an array needs an index");
            return *slot_of(node);
        case T::Unary: {
            Value value = eval(*node.args[0]);
            if (node.op == ast::Op::Not) {
                if (value.type != TypeId::Bool)
                    fail(node.line, "! needs a bool");
                value.v[0] = value.v[0] != 0.0F ? 0.0F : 1.0F;
                return value;
            }
            const bool numeric = ast::is_vector_or_scalar(value.type) ||
                                 ast::is_matrix(value.type);
            if (!numeric || ast::kind_of(value.type) == ast::Kind::Bool)
                fail(node.line, "unary - needs a number");
            if (node.op == ast::Op::Neg)
                for (int i = 0; i < ast::count_of(value.type); ++i)
                    value.v[static_cast<std::size_t>(i)] =
                        -value.v[static_cast<std::size_t>(i)];
            return value;
        }
        case T::Binary: {
            const auto a = eval(*node.args[0]);
            const auto b = eval(*node.args[1]);
            return binary(node.op, a, b, node.line);
        }
        case T::Logical: {
            const auto a = eval(*node.args[0]);
            if (a.type != TypeId::Bool)
                fail(node.line, "&& and || need bools");
            const bool left = a.v[0] != 0.0F;
            if ((node.op == ast::Op::And && !left) ||
                (node.op == ast::Op::Or && left))
                return ast::make_bool(left);
            const auto b = eval(*node.args[1]);
            if (b.type != TypeId::Bool)
                fail(node.line, "&& and || need bools");
            return ast::make_bool(b.v[0] != 0.0F);
        }
        case T::Assign: {
            if (node.op == ast::Op::None) {
                const auto value = eval(*node.args[1]);
                const auto target = lvalue(*node.args[0]);
                write(target, value, node.line);
                return value;
            }
            const auto target = lvalue(*node.args[0]);
            const auto current = read(target);
            const auto operand = eval(*node.args[1]);
            const auto value = binary(node.op, current, operand, node.line);
            write(target, value, node.line);
            return value;
        }
        case T::Conditional: {
            const auto condition = eval(*node.args[0]);
            if (condition.type != TypeId::Bool)
                fail(node.line, "?: needs a bool condition");
            return eval(*node.args[condition.v[0] != 0.0F ? 1 : 2]);
        }
        case T::Call:
            return call(node);
        case T::Builtin: {
            Arguments args { *this, node.args.size(), node.line };
            for (std::size_t i = 0; i < node.args.size(); ++i)
                args[i] = eval(*node.args[i]);
            return builtin(node.builtin, args.data(),
                static_cast<int>(node.args.size()), node.line);
        }
        case T::Construct: {
            Arguments args { *this, node.args.size(), node.line };
            for (std::size_t i = 0; i < node.args.size(); ++i)
                args[i] = eval(*node.args[i]);
            return construct(node.construct, args.data(),
                static_cast<int>(node.args.size()), node.line);
        }
        case T::Index: {
            if (node.array_index) {
                const auto& array = *node.args[0];
                const auto index =
                    index_of(*node.args[1], static_cast<int>(array.array_size));
                return *(slot_of(array) + index);
            }
            const auto value = eval(*node.args[0]);
            if (ast::is_matrix(value.type)) {
                const int order = ast::dimension(value.type);
                const auto index = index_of(*node.args[1], order);
                Value column =
                    ast::make(ast::vector_of(ast::Kind::Float, order));
                for (int row = 0; row < order; ++row)
                    column.v[static_cast<std::size_t>(row)] =
                        value.v[static_cast<std::size_t>(index * order + row)];
                return column;
            }
            if (!ast::is_vector_or_scalar(value.type) ||
                ast::count_of(value.type) < 2)
                fail(node.line, "this value cannot be indexed");
            const auto index =
                index_of(*node.args[1], ast::count_of(value.type));
            Value element =
                ast::make(ast::vector_of(ast::kind_of(value.type), 1));
            element.v[0] = value.v[static_cast<std::size_t>(index)];
            return element;
        }
        case T::Swizzle: {
            const auto value = eval(*node.args[0]);
            if (!ast::is_vector_or_scalar(value.type) ||
                ast::count_of(value.type) < 2)
                fail(node.line, "only a vector can be swizzled");
            Value result = ast::make(
                ast::vector_of(ast::kind_of(value.type), node.swizzle_count));
            for (int i = 0; i < node.swizzle_count; ++i) {
                const auto component =
                    node.swizzle[static_cast<std::size_t>(i)];
                if (component >= ast::count_of(value.type))
                    fail(node.line, "swizzle component out of range");
                result.v[static_cast<std::size_t>(i)] = value.v[component];
            }
            return result;
        }
        case T::Increment: {
            const auto target = lvalue(*node.args[0]);
            const auto before = read(target);
            Value one =
                ast::make(ast::is_matrix(before.type)
                              ? TypeId::Float
                              : ast::vector_of(ast::kind_of(before.type), 1));
            one.v[0] = 1.0F;
            const auto after = binary(node.op, before, one, node.line);
            write(target, after, node.line);
            return node.prefix ? after : before;
        }
        case T::Sequence: {
            Value last;
            for (const auto& argument : node.args)
                last = eval(*argument);
            return last;
        }
        }
        fail(node.line, "unsupported expression");
    }

    // Statements ---------------------------------------------------------

    bool truth(const ast::Node& condition)
    {
        const auto value = eval(condition);
        if (value.type != TypeId::Bool)
            fail(condition.line, "a condition must be a bool");
        return value.v[0] != 0.0F;
    }

    Flow exec(const ast::Statement& statement)
    {
        const Nest nest { *this, statement.line };
        using T = ast::Statement::Type;
        switch (statement.type) {
        case T::Block:
            for (const auto& child : statement.children) {
                const auto flow = exec(*child);
                if (flow != Flow::Normal)
                    return flow;
            }
            return Flow::Normal;
        case T::Declare: {
            auto* target = &stack[base + statement.slot];
            if (statement.array_size != 0) {
                for (std::uint32_t i = 0; i < statement.array_size; ++i)
                    target[i] = ast::make(statement.declared);
                return Flow::Normal;
            }
            if (statement.expression) {
                const auto value = eval(*statement.expression);
                if (value.type != statement.declared)
                    fail(statement.line,
                        std::string { "cannot initialise " } +
                            std::string { type_name(statement.declared) } +
                            " with " + std::string { type_name(value.type) });
                *target = value;
            } else {
                *target = ast::make(statement.declared);
            }
            return Flow::Normal;
        }
        case T::Expression:
            (void)eval(*statement.expression);
            return Flow::Normal;
        case T::If:
            if (truth(*statement.expression))
                return exec(*statement.children[0]);
            if (statement.children.size() > 1)
                return exec(*statement.children[1]);
            return Flow::Normal;
        case T::For: {
            if (statement.children[0]) {
                const auto flow = exec(*statement.children[0]);
                if (flow != Flow::Normal)
                    return flow;
            }
            for (;;) {
                if (statement.expression && !truth(*statement.expression))
                    break;
                tick(statement.line);
                const auto flow = exec(*statement.children[1]);
                if (flow == Flow::Break)
                    break;
                if (flow == Flow::Return || flow == Flow::Discard)
                    return flow;
                if (statement.step)
                    (void)eval(*statement.step);
            }
            return Flow::Normal;
        }
        case T::While:
            while (truth(*statement.expression)) {
                tick(statement.line);
                const auto flow = exec(*statement.children[0]);
                if (flow == Flow::Break)
                    break;
                if (flow == Flow::Return || flow == Flow::Discard)
                    return flow;
            }
            return Flow::Normal;
        case T::DoWhile:
            do {
                tick(statement.line);
                const auto flow = exec(*statement.children[0]);
                if (flow == Flow::Break)
                    break;
                if (flow == Flow::Return || flow == Flow::Discard)
                    return flow;
            } while (truth(*statement.expression));
            return Flow::Normal;
        case T::Return:
            returned = statement.expression ? eval(*statement.expression)
                                            : ast::make(TypeId::Void);
            return Flow::Return;
        case T::Break:
            return Flow::Break;
        case T::Continue:
            return Flow::Continue;
        case T::Discard:
            return Flow::Discard;
        }
        return Flow::Normal;
    }
};

// Module ---------------------------------------------------------------

Module::Module(std::shared_ptr<const Impl> impl)
    : impl_(std::move(impl))
{
}

Module::~Module() = default;

std::shared_ptr<const Module> Module::compile(
    std::string_view source, Stage stage, std::string& log)
{
    auto impl = std::make_shared<Impl>();
    if (source.size() > maximum_source_bytes) {
        log += "ERROR: 0:1: the shader source is longer than " +
               std::to_string(maximum_source_bytes) + " bytes\n";
        return nullptr;
    }
    try {
        Parser parser { Lexer { source }.run(), stage, *impl };
        parser.unit();
        for (const auto& variable : impl->variables)
            if (variable.storage == Storage::Builtin &&
                variable.name != "gl_FragCoord" &&
                variable.name != "gl_FrontFacing" &&
                variable.name != "gl_PointCoord")
                for (std::uint32_t i = 0;
                    i < std::max<std::uint32_t>(variable.array_size, 1U); ++i)
                    impl->output_slots.push_back(variable.slot + i);
    } catch (const CompileError& error) {
        log += "ERROR: 0:" + std::to_string(error.line) + ": " + error.message +
               "\n";
        return nullptr;
    }
    return std::make_shared<const Module>(std::move(impl));
}

Stage Module::stage() const { return impl_->stage; }

std::span<const Variable> Module::variables() const { return impl_->variables; }

const Variable* Module::find(std::string_view name) const
{
    for (const auto& variable : impl_->variables)
        if (variable.name == name)
            return &variable;
    return nullptr;
}

// Instance -------------------------------------------------------------

Instance::Instance(std::shared_ptr<const Module> module)
    : module_(std::move(module))
    , state_(std::make_unique<State>(module_->impl()))
{
}

Instance::~Instance() = default;
Instance::Instance(Instance&&) noexcept = default;
Instance& Instance::operator=(Instance&&) noexcept = default;

std::span<Value> Instance::values(const Variable& variable)
{
    return { state_->globals.data() + variable.slot,
        std::max<std::size_t>(variable.array_size, 1U) };
}

std::span<const Value> Instance::values(const Variable& variable) const
{
    return { state_->globals.data() + variable.slot,
        std::max<std::size_t>(variable.array_size, 1U) };
}

bool Instance::run(const TextureAccess* textures)
{
    discarded_ = false;
    error_.clear();
    auto& state = *state_;
    const auto& impl = module_->impl();
    state.textures = textures;
    state.steps = 0;
    state.step_limit = std::min<std::uint64_t>(maximum_steps,
        maximum_draw_steps - std::min(total_steps_, maximum_draw_steps));
    state.base = 0;
    state.top = 0;
    state.depth = 0;
    state.nesting = 0;
    // However the run ends, its steps count against the draw.
    struct Settle {
        std::uint64_t& total;
        const State& state;
        ~Settle() { total += std::min(state.steps, state.step_limit); }
    } const settle { total_steps_, state };
    for (const auto slot : impl.output_slots)
        state.globals[slot] = ast::make(state.globals[slot].type);
    try {
        for (const auto& initializer : impl.initializers) {
            const auto value = state.eval(*initializer.value);
            if (value.type != initializer.type)
                fail(initializer.value->line, "global initializer type");
            state.globals[initializer.slot] = value;
        }
        const auto& main = *impl.main;
        // The compiler refuses a bigger frame; the run does not rest on that.
        if (main.frame_size > stack_values)
            fail(
                main.body->line, "the stack is too small for main's variables");
        state.top = main.frame_size;
        const auto flow = state.exec(*main.body);
        if (flow == Flow::Discard) {
            discarded_ = true;
            return false;
        }
    } catch (const State::Discarded&) {
        discarded_ = true;
        return false;
    } catch (const RunError& error) {
        error_ = "runtime error at line " + std::to_string(error.line) + ": " +
                 error.message;
        return false;
    }
    return true;
}

} // namespace shade::glsl
