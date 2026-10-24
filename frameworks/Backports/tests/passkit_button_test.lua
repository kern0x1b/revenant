local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local frameworks = path.join(workspace.sdk(), "System", "Library", "Frameworks")
local SOURCE = "src/PassKit/PKPaymentButton8.m"
local INITIALIZER = "- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style\n{"

local function header(name)
    return io.readfile(path.join(frameworks, "PassKit.framework", "Headers", name))
end

local function contains(text, needle, label)
    assert(text:find(needle, 1, true), label .. " does not contain " .. needle)
end

local function replaced(text, from, to)
    local start, stop = text:find(from, 1, true)
    assert(start, "the negative control has no " .. from)
    return text:sub(1, start - 1) .. to .. text:sub(stop + 1)
end

local SDK_NEEDLES = {
    "@interface PKPaymentButton : UIButton",
    "+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle;",
    "- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style",
    "@property (nonatomic, assign) CGFloat cornerRadius",
}

local SOURCE_NEEDLES = {
    "@implementation PKPaymentButton",
    "+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle\n",
    "+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle disableCardArt:(BOOL)disableCardArt",
    INITIALIZER,
    "- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style disableCardArt:(BOOL)disableCardArt",
    "- (CGFloat)cornerRadius",
    "- (void)setCornerRadius:(CGFloat)cornerRadius",
    "- (void)revenantReportUnavailable",
    "RevenantPassKitNoHardwareError()",
}

local ENUM_NEEDLES = {
    "PKPaymentButtonStyleWhite = 0,",
    "PKPaymentButtonStyleWhiteOutline,",
    "PKPaymentButtonStyleBlack,",
    "PKPaymentButtonTypePlain = 0,",
}

function main()
    local button = header("PKPaymentButton.h")
    local constants = header("PKConstants.h")
    for _, needle in ipairs(SDK_NEEDLES) do
        contains(button, needle, "the SDK PassKit button header")
    end
    for _, needle in ipairs(ENUM_NEEDLES) do
        contains(constants, needle, "the SDK PassKit constants header")
    end

    local source = io.readfile(path.join(backports, SOURCE))
    for _, needle in ipairs(SOURCE_NEEDLES) do
        contains(source, needle, "the PassKit button backport")
    end

    local broken = replaced(source, "paymentButtonStyle:(PKPaymentButtonStyle)style\n{", "paymentButtonLook:(PKPaymentButtonStyle)style\n{")
    assert(not broken:find(INITIALIZER, 1, true), "the negative control with a renamed initializer still matches the contract")
end
