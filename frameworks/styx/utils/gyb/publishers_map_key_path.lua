-- Publishers.MapKeyPath.swift.gyb as a Lua generator: the template's text, with the loops of its %-lines written as Lua.
-- The output is GENERATED-Publishers.MapKeyPath.swift, which the Combine target compiles.
local support = import("support", {rootdir = os.scriptdir(), anonymous = true})
local python_random = import("python_random", {rootdir = os.scriptdir(), anonymous = true})

local OUT = path.join(os.scriptdir(), "..", "..", "Sources", "Combine", "Publishers", "GENERATED-Publishers.MapKeyPath.swift")

local out, env = {}, {}

local function emit(text)
    out[#out + 1] = support.fill(text, env)
end

env.template_header = support.header()

emit([==[
${template_header}
//
//  Publishers.MapKeyPath.swift.gyb
//  
//
//  Created by Sergej Jaskiewicz on 03/10/2019.
//

// swiftlint:disable large_tuple

]==])
-- the (arity, cardinal, ordinal) of each instantiation, and the helpers the template calls
local instantiations = {{1, "", ""}, {2, "two", "second "}, {3, "three", "third "}}

local function suffix_variadic(name, index, arity)
    return name .. (arity == 1 and "" or tostring(index))
end

local function list_with_suffix_variadic(name, arity)
    local names = {}
    for i = 0, arity - 1 do
        names[#names + 1] = suffix_variadic(name, i, arity)
    end
    return names
end

local function key_path_var(index, arity)
    return suffix_variadic("keyPath", index, arity)
end

local function make_publisher_name(arity)
    return suffix_variadic("MapKeyPath", arity, arity)
end

local function make_output_types(arity)
    return list_with_suffix_variadic("Output", arity)
end

-- the dice the first loop prints are drawn from Python's random.Random(0), in the order the instantiations come
local rng = python_random.new(0)
emit([==[
extension Publisher {
]==])
for _, row in ipairs(instantiations) do
    local arity, cardinal = row[1], row[2]
    local result_types = list_with_suffix_variadic("Result", arity)
    env.cs_result_types = table.concat(result_types, ", ")

    local method_args, init_args = {}, {}
    for i = 0, arity - 1 do
        method_args[#method_args + 1] = "_ " .. key_path_var(i, arity) .. ": KeyPath<Output, " .. result_types[i + 1] .. ">"
        init_args[#init_args + 1] = key_path_var(i, arity) .. ": " .. key_path_var(i, arity)
    end
    env.method_args_joined = table.concat(method_args, ",\n        ")
    env.init_args_joined = table.concat(init_args, ",\n            ")

    env.publisher_name = make_publisher_name(arity)

    env.doc_comment_suffix = arity == 1 and "value of the key path" or ("values of " .. cardinal .. " key paths as a tuple")

    local ints = {}
    for i = 1, arity do
        ints[i] = "Int"
    end
    env.doc_output_values = arity == 1 and "the value of this `Int`"
    or ("these " .. cardinal .. " values (as an `(" .. table.concat(ints, ", ") .. ")` tuple)")

    local example_dice_roll_properties = {"die"}
    if arity > 1 then
        example_dice_roll_properties = {}
        for i = 1, arity do
            example_dice_roll_properties[i] = "die" .. i
        end
    end
    local listed = {}
    for i, name in ipairs(example_dice_roll_properties) do
        listed[i] = "\\." .. name
    end
    env.map_arguments = table.concat(listed, ", ")
    env.underscores = string.rep("_:", arity)

    local enumerated
    if arity == 1 then
        enumerated = "`die` member"
    elseif arity == 2 then
        enumerated = "`die1` and `die2` members"
    else
        local parts = {}
        for i = 1, arity - 1 do
            parts[i] = "`" .. example_dice_roll_properties[i] .. "`, "
        end
        enumerated = table.concat(parts) .. "and `" .. example_dice_roll_properties[arity] .. "` members"
    end
    env.enumerated_example_dice_roll_properties = enumerated

    local rolls = {}
    for i, name in ipairs(example_dice_roll_properties) do
        rolls[i] = name .. ": Int.random(in: 1...6)"
    end
    env.dice_roll_init = table.concat(rolls, ",\n    ///                                 ")

    emit([==[
    /// Publishes the ${doc_comment_suffix}.
    ///
    /// In the following example, the `map(${underscores})` operator uses the Swift
    /// key path syntax to access the ${enumerated_example_dice_roll_properties}
    /// of the `DiceRoll` structure published by the `Just` publisher.
    ///
    /// The downstream sink subscriber receives only
    /// ${doc_output_values},
    /// not the entire `DiceRoll`.
    ///
    ///     struct DiceRoll {
]==])
    for _, prop in ipairs(example_dice_roll_properties) do
        env.prop = prop
        emit([==[
    ///         let ${prop}: Int
]==])
    end
    emit([==[
    ///     }
    ///
    ///     cancellable = Just(DiceRoll(${dice_roll_init}))
    ///         .map(${map_arguments})
]==])
    if arity == 1 then
        emit([==[
    ///         .sink {
    ///             print ("Rolled: \($0)")
    ///         }
]==])
    else
        local closure_args, interpolated = {}, {}
        for i = 0, arity - 1 do
            closure_args[i + 1] = "values." .. i
            interpolated[i + 1] = "\\(" .. closure_args[i + 1] .. ")"
        end
        env.rolled_values = table.concat(interpolated, ", ")
        env.sum_expression = table.concat(closure_args, " + ")
        emit([==[
    ///         .sink { values in
    ///             print("""
    ///             Rolled: ${rolled_values} \
    ///             (total \(${sum_expression}))
    ///             """)
    ///         }
]==])
    end
    local random_numbers = {}
    for i = 1, arity do
        random_numbers[i] = python_random.randint(rng, 1, 6)
    end
    local printed, total = {}, 0
    for i, n in ipairs(random_numbers) do
        printed[i] = tostring(n)
        total = total + n
    end
    env.random_numbers_printed = table.concat(printed, ", ")
    .. (arity == 1 and " (or some other random value)" or (" (total: " .. total .. ')" (or other random values)'))
    emit([==[
    ///     // Prints "Rolled: ${random_numbers_printed}.
    ///
    /// - Parameters:
]==])
    for i = 0, arity - 1 do
        env.key_path = key_path_var(i, arity)
        env.ordinal = (i == 1 and arity < 3) and "another " or ("a " .. instantiations[i + 1][3])
        emit([==[
    ///    - ${key_path}: The key path of ${ordinal}property on `Output`.
]==])
    end
    emit([==[
    /// - Returns: A publisher that publishes the ${doc_comment_suffix}.
    public func map<${cs_result_types}>(
        ${method_args_joined}
    ) -> Publishers.${publisher_name}<Self, ${cs_result_types}> {
        return .init(
            upstream: self,
            ${init_args_joined}
        )
    }
]==])
end
emit([==[
}

extension Publishers {
]==])
for _, row in ipairs(instantiations) do
    local arity, cardinal = row[1], row[2]
    env.doc_comment_suffix = arity == 1 and "value of a key path" or ("values of " .. cardinal .. " key paths as a tuple")

    local output_types = make_output_types(arity)
    env.cs_output_types = table.concat(output_types, ", ")

    env.publisher_name = make_publisher_name(arity)
    emit([==[

    /// A publisher that publishes the ${doc_comment_suffix}.
    public struct ${publisher_name}<Upstream: Publisher, ${cs_output_types}>: Publisher {

]==])
    if arity ~= 1 then
        emit([==[
        public typealias Output = (${cs_output_types})

]==])
    end
    emit([==[
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

]==])
    for i = 0, arity - 1 do
        env.key_path = key_path_var(i, arity)
        env.output_type = output_types[i + 1]
        env.ordinal = instantiations[i + 1][3]
        emit([==[
        /// The key path of a ${ordinal}property to publish.
        public let ${key_path}: KeyPath<Upstream.Output, ${output_type}>

]==])
    end
    emit([==[
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Failure == Downstream.Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, parent: self))
        }
    }
]==])
end
emit([==[
}
]==])
for _, row in ipairs(instantiations) do
    local arity = row[1]
    local output_types = make_output_types(arity)
    env.cs_output_types = table.concat(output_types, ", ")

    env.publisher_name = make_publisher_name(arity)
    emit([==[

extension Publishers.${publisher_name} {

    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

]==])
    for i = 0, arity - 1 do
        env.key_path = key_path_var(i, arity)
        env.output_type = output_types[i + 1]
        emit([==[
        private let ${key_path}: KeyPath<Input, ${output_type}>

]==])
    end
    emit([==[
        let combineIdentifier = CombineIdentifier()

        fileprivate init(
            downstream: Downstream,
            parent: Publishers.${publisher_name}<Upstream, ${cs_output_types}>
        ) {
            self.downstream = downstream
]==])
    for i = 0, arity - 1 do
        env.key_path = key_path_var(i, arity)
        emit([==[
            self.${key_path} = parent.${key_path}
]==])
    end
    emit([==[
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
]==])
    local output_components = {}
    for i = 0, arity - 1 do
        output_components[i + 1] = "input[keyPath: " .. key_path_var(i, arity) .. "]"
    end
    env.output_components_joined = table.concat(output_components, ",\n                ")
    emit([==[
            let output = (
                ${output_components_joined}
            )
            return downstream.receive(output)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

]==])
    env.inner_description = "ValueForKey" .. (arity == 1 and "" or "s")
    emit([==[
        var description: String { return "${inner_description}" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
]==])
    for i = 0, arity - 1 do
        env.key_path = key_path_var(i, arity)
        emit([==[
                ("${key_path}", ${key_path}),
]==])
    end
    emit([==[
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
]==])
end

support.write(OUT, table.concat(out))
