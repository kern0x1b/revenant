# Eidolon

Своя реализация SwiftUI для iOS 6 armv7 поверх UIKit шестой системы. Имя — εἴδωλον, «образ, облик»:
призрачный двойник у Гомера; в семье Charon, Shade и Revenant (Revenant — это движок WebKit, не этот проект).

**Это не SwiftUI Apple.** Ни строки кода Apple здесь нет и не будет: у настоящего SwiftUI нет исходников,
он существует только как бинарник для arm64, и на iOS 6 он не переносится (разбор и цифры — в `../docs/research.md`).

**Модуль называется `SwiftUI`, а не Eidolon, и это обязательно.** От имени модуля зависят манглы всех символов,
которые приложение берёт у SwiftUI: с другим именем приложение не собралось бы без правки `import SwiftUI`
и не связалось бы как гостевое для рекомпилятора. Eidolon — имя проекта, каталога, целей и документов.

Совместимость двух видов:
- **по исходникам** — приложение на обычном синтаксисе SwiftUI компилируется против этого модуля без правок текста;
- **по поверхности символов** для гостевой сборки рекомпилятора — модуль, собранный с библиотечной эволюцией,
  удовлетворяет все 64 символа SwiftUI, которые берёт подопытное приложение Apple-сборки (`../bridge/README.md`).
  Раскладки внутренних типов и точки входа графа у нас свои.

## Состояние

Прототип. Достаточно для экрана со списком, навигацией, состоянием и наблюдаемой моделью;
не достаточно для произвольного чужого кода.

### Что поддержано, что игнорируется, чего нет

Счёт ведётся скриптом `coverage.py` по интерфейсам SwiftUI и SwiftUICore из SDK 26.2, которые перечисляет `../bridge/types-surface.py` (1344 публичных типа и typealias). Список модификаторов `View` (311) остаётся ручным: он заведён при первом коммите и с интерфейса 16.4 не менялся.
На сегодня: **664 типов** и **311 модификаторов**, из них **206 действуют**, 0 заглушки (пишут в журнал), 105 объявлены и игнорируются.
Из того, что Apple объявляет доступным на iOS: **646 из 1208 типов** и **289 из 289 модификаторов**, из них **202 действуют**, 0 заглушки, 87 игнорируются
(остальное в интерфейсе помечено `@available(iOS, unavailable)` — это macOS, tvOS и watchOS; список типов строит `../bridge/types-surface.py`, список модификаторов — `../bridge/ios-surface.py`).

**Что эти числа не говорят.** Счёт выше — по *именам* типов и модификаторов. По декларациям картина строже:
типизированный разбор `swift-api-digester` (`../bridge/api-surface.sh`, колонки отчёта — `../bridge/api-diff.lua`)
сравнивает интерфейс Apple SwiftUI для iOS 16.4 с нашим модулем по подписи каждой декларации и на 19.09 находит
**из 4740 деклараций Apple 3233 (68%) вызываются как у Apple, 314 (7%) есть, но с другой подписью, 927 (20%) нет и их ещё писать, 266 (6%) — типы, которых в iOS 6 быть не может (сцены, виджеты, документы, роторы, AttributedString…), закрытый список с причинами в `bridge/not-applicable.txt`** (вызов, который
компилируется у нас благодаря значениям параметров по умолчанию, отсутствующим не считается). Заметная часть первых —
то, чему в iOS 6 нечему соответствовать (Widgets, документы, окна, `UIHostingConfiguration`, роторы доступности);
остальное — работа, которая ещё не сделана: перегрузки вроде `Stepper`, `TextField` с `prompt:`/`axis:`, 48 ключей
`EnvironmentValues`, 28 случаев `BlendMode` вместо наших семи, `Table` целиком. Этот список — рабочая очередь;
закрытый перечень «нечему соответствовать» с причинами будет вестись рядом, и сборка будет падать, если
отсутствующее не в нём и не в очереди.

**Действуют** (видны на экране и в тестах):

| Область | Что есть |
|---|---|
| Описание | `View`, `ViewBuilder` (вариадический), `if`/`else`, `TupleView`, `Group`, `AnyView`, `EmptyView`, `ViewModifier`, `ModifiedContent` |
| Состояние | `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@EnvironmentObject`, `@Environment` по ключам, `@AppStorage`, `@FocusState`, `@GestureState`, `ObservableObject`/`@Published`; стандартные ключи окружения: `colorScheme`, `locale`, `calendar`, `timeZone`, `isEnabled`, `layoutDirection`, `sizeCategory`, `controlSize`, `horizontalSizeClass`, `displayScale`, `openURL`, `dismiss`, `editMode`, `font`, `multilineTextAlignment`, `dynamicTypeSize` (категория задаёт размер текста всего поддерева — шрифта заголовка строки, плашки, текста в поле и в `Canvas` тоже; берётся коэффициент из таблицы Dynamic Type для основного шрифта: 14, 15, 16, 17, 19, 21 и 23 пункта против 17, то есть 0.82…1.35. Таблица своя для каждого стиля текста, а здесь один коэффициент на все стили), `redactionReasons`, `isSearching`, `dynamicTypeSize` (категория задаёт размер текста всего поддерева — шрифта заголовка строки, плашки, текста в поле и в `Canvas` тоже; берётся коэффициент из таблицы Dynamic Type для основного шрифта: 14, 15, 16, 17, 19, 21 и 23 пункта против 17, то есть 0.82…1.35. Таблица Apple своя для каждого стиля текста, а здесь один коэффициент на все стили — в iOS 6 у шрифтов нет метрик, которые бы масштабировали подпись и заголовок по-разному) |
| Представления | `Text` (шрифт, цвет, начертание, подчёркивание, зачёркивание, регистр, склейка `+`, даты), `Button`, `Toggle`, `TextField`, `SecureField`, `TextEditor`, `Slider`, `Stepper`, `ProgressView` (с подписью и текущим значением, по интервалу времени с `DefaultDateProgressLabel`), `Gauge`, `Picker` (сегменты), `DatePicker`, `MultiDatePicker` (сетка месяца на нашем `Grid`), `Menu`, `Link`, `ShareLink` (`UIActivityViewController`), `Label`, `GroupBox`, `ControlGroup`, `DisclosureGroup`, `Image` (с `resizable`, `aspectRatio`), `AsyncImage` (`NSURLConnection`), `Color`, `Divider`, `Spacer`, `ForEach` с идентичностью и по привязке (`ForEach($items)`, `List($items)`, `editActions:` удаляют и двигают через привязку), `TimelineView`, `Canvas` с настоящим `GraphicsContext` (градиентные заливки, текст и картинки через `resolve`, символы, `clip(options: .inverse)`, `clipToLayer`, `blendMode`, фильтр тени; размытие и цветовые фильтры CoreGraphics iOS 6 не умеет — пишут в журнал), `AttributeScopes.SwiftUIAttributes` и восемь его атрибутов (`font`, `foregroundColor`, `backgroundColor`, `strikethroughStyle`, `underlineStyle`, `kern`, `tracking`, `baselineOffset`): имена и типы значений как в интерфейсе 26.2, и ключ `NSAttributedString` этого релиза, под который атрибут пишется |
| Фигуры | `Shape`, `Path`, `Rectangle`, `RoundedRectangle`, `Circle`, `Ellipse`, `Capsule`, `AnyShape`, `fill`/`stroke`/`strokeBorder` со `ShapeStyle` и полным `StrokeStyle` (пунктир, фаза, концы, стыки), заливка и обводка фигур градиентом, преобразования (`offset`, `scale`, `rotation`, `transform`), `inset(by:)`, `Gradient`, `LinearGradient`, `RadialGradient`, `EllipticalGradient`, `AngularGradient` (секторами — конического градиента в iOS 6 нет), `AnyGradient` и `Color.gradient`, `AnyShapeStyle`, иерархические стили `.primary`…`.quaternary`, `.selection`, `.tint`, `Material` (полупрозрачная заливка без размытия, пишет в журнал), `ShadowStyle` (`.drop` — тень слоя; `.inner` пишет в журнал) |
| Раскладка | `VStack`, `HStack`, `ZStack`, `HStackLayout`, `VStackLayout`, `ZStackLayout` (и через `AnyLayout`), `LazyVStack`, `LazyHStack`, `LazyVGrid`, `LazyHGrid`, `Grid` и `GridRow` с выравниванием колонок по всем строкам, строками на всю ширину, `gridCellColumns`, `gridCellAnchor`, `gridCellUnsizedAxes`, `gridColumnAlignment`, `ScrollView`, `ScrollViewReader` со `scrollTo(id, anchor:)` в `ScrollView` и в `List`, `GeometryReader` с `frame(in:)` в `.local`, `.global` и именованном пространстве (`coordinateSpace(name:)`), `ViewThatFits`, `padding` по сторонам, полный `frame`, `fixedSize`, `layoutPriority`, `aspectRatio`, `alignmentGuide` и свои выравнивания через `AlignmentID`, `margins`, `baselineOffset`, протокол `Layout` со своими раскладками (`ProposedViewSize`, `LayoutSubviews`, `AnyLayout`, `LayoutValueKey` и `layoutValue`) |
| Списки | `List` с выбором (`selection:` одной строки и множеством), `Table` (на iPhone — как у Apple: одна первая колонка списком; `TableColumn`, строители колонок и строк, `tableStyle`), `Form`, `Section` с заголовком и футером (`headerProminence(.increased)` — свой крупный заголовок секции), `listItemTint`, удаление и перемещение строк (`remove(atOffsets:)`, `move(fromOffsets:toOffset:)`), `deleteDisabled`, `moveDisabled`, `swipeActions` (одно действие — кнопка свайпа с его названием; несколько — кнопка «More» и `UIActionSheet` со всеми), `Button(role:)`, `EditButton`, `refreshable`, `searchable` (в списке — в шапке таблицы, у прочего содержимого — строка поиска над ним), `searchScopes` (кнопки области `UISearchBar`), `searchSuggestions` и `searchCompletion` (пока поле поиска активно, подсказки — своим списком поверх таблицы или вместо содержимого; строка с `searchCompletion` по нажатию подставляет текст), `isSearching` в окружении, `buttonStyle` с `PrimitiveButtonStyle` и `Button(configuration)`, фон и отступы строки, `listRowSeparator` и `listRowSeparatorTint` (строка, которая прячет разделитель или красит его, рисует линию сама — там, где `UITableView` рисует свою: точкой у нижнего края строки), кэш ячеек |
| Навигация | `NavigationView`, `NavigationLink` (касанием вне списка тоже, `isActive`, `tag`/`selection`), `NavigationSplitView` (на iPhone — стек: выбор строки в `List(selection:)` открывает следующую колонку, возврат снимает выбор), `OutlineGroup` и `List(_:children:)`, `navigationTitle`, `navigationBarItems`, `toolbar`, `TabView` с `tabItem` и `badge`, `TabView` со стилем `.page` (листание `UIScrollView` и точки `UIPageControl`, `indexViewStyle`), `navigationBarHidden` |
| Система | `onOpenURL` (делегат приложения передаёт URL обработчикам на экране), `statusBarHidden` и старое `statusBar(hidden:)` (`setStatusBarHidden`), `toolbarColorScheme` для панели навигации (`UIBarStyleBlack`; у `UITabBar` iOS 6 стиля нет — пишет в журнал), `submitLabel` (`returnKeyType`; `.continue` пишет в журнал — такой клавиши в iOS 6 нет), `submitScope(.block)` у поля на несколько строк (клавиша Return выполняет отправку, а не добавляет строку — `textView(_:shouldChangeTextIn:replacementText:)`), `badge` (у вкладки — `badgeValue`, у строки списка — плашка справа), `scrollContentBackground(.hidden)`, `redacted`/`unredacted`/`privacySensitive` (заглушки-плашки вместо текста и картинок), `help` (как подсказка доступности, как у Apple на iOS), старое написание `accessibility(label:hint:value:hidden:identifier:addTraits:removeTraits:)` |
| Время | `TimelineView` по расписаниям Apple (`periodic`, `everyMinute`, `animation` с `minimumInterval` и `paused`, `explicit`) и свои `TimelineSchedule` через `entries(from:mode:)` |
| Модальность | `.sheet` (в том числе `sheet(item:)`), `.fullScreenCover`, `.alert` (родной `UIAlertView`), `.actionSheet`, `.confirmationDialog`, `contextMenu`, `presentationMode`, `presentationBackground` (экран модального экрана красится тем цветом, а не белым, каким его красит система) |
| Оформление | фон и накладка стилем (`.background(.ultraThinMaterial)`, `.background(.blue, in: Capsule())`, `.background(in:)` с `backgroundStyle`), `foregroundStyle` со `ShapeStyle`, `containerShape` для `ContainerRelativeShape`, `contentTransition` (смена текста наплывом `CATransition`), `projectionEffect` (`CATransform3D`), `compositingGroup` (растеризация слоя — так в iOS 6 получается групповая прозрачность), `buttonBorderShape` для `bordered`/`borderedProminent`, `grayscale`, `saturation`, `brightness`, `contrast`, `hueRotation`, `colorInvert`, `colorMultiply`, `luminanceToAlpha` и `blur` (Core Image поверх картинки, в которую нарисован вид; картинка кладётся поверх содержимого и касаний не перехватывает, так что отфильтрованная кнопка остаётся кнопкой), `opacity`, `cornerRadius`, `border`, `shadow`, `clipped`, `clipShape`, `offset`, `rotationEffect`, `scaleEffect`, `overlay`, `background` видом, `hidden`, `zIndex`, `drawingGroup`, `redacted` |
| Жесты | Движок с типизированными событиями: `TapGesture`, `SpatialTapGesture`, `LongPressGesture` (нажатие с момента касания, а не через `minimumDuration`), `DragGesture` (с `minimumDistance` и `coordinateSpace`), `MagnificationGesture`, `RotationGesture`; `onChanged`, `onEnded`, `map`, `updating` с `@GestureState` (значение сбрасывается, когда жест кончился или отменён), `simultaneously`, `sequenced` (второй жест ждёт первого), `exclusively` (второй ждёт, пока не откажет первый), `AnyGesture`, жесты, собранные через `body`; `gesture`, `simultaneousGesture`, `highPriorityGesture` с `including:`; `onTapGesture`, `onLongPressGesture` с `onPressingChanged`; `contentShape` (форма, в которой жест принимает касание) |
| Анимация | `Keyframes` и `KeyframeTrack` с `KeyframeTrackContent`, `KeyframesBuilder`, `CubicKeyframe`, `LinearKeyframe`, `SpringKeyframe`, `MoveKeyframe`, `KeyframeAnimator` и `PhaseAnimator` (вид показывает значение, которое ведёт по кадрам его трек, фаза живёт столько, сколько длится её анимация), `CustomAnimation` с `AnimationContext` и `AnimationState`, `Animation.custom` (`animate`, `velocity`, `shouldMerge`, `base`), `Transaction.addAnimationCompletion(criteria:_:)` (замыкание выполняется, когда анимация транзакции кончилась), `Animation` (`.linear`, `.easeIn`, `.easeOut`, `.easeInOut`, `.spring` — по `response:dampingFraction:`, по `duration:bounce:` и по `Spring`, `.interactiveSpring`, `.interpolatingSpring`, `.smooth`, `.snappy`, `.bouncy`, `timingCurve(_:duration:)` для `UnitCurve` и для четырёх точек, `delay`, `speed`, `repeatCount`, `repeatForever`, `logicallyComplete`), `Spring` (все четыре способа построить, `value`/`velocity`/`force`/`update` для `VectorArithmetic` и для `Animatable`, `settlingDuration`, `smooth`/`snappy`/`bouncy`), `UnitCurve` (кривые Безье и три круговые, `value`, `velocity`, `inverse`, `bezier(startControlPoint:endControlPoint:)`), `withAnimation`, `.animation` поверх `UIView.animate`, `repeatForever`, `repeatCount` (с `autoreverses`), `transition`, `matchedGeometryEffect` с `@Namespace` (новый вид едет из места старого); **данные `Animatable` интерполируются кадр за кадром** у своих `Shape` (`animatableData`), `GeometryEffect`, `ViewModifier & Animatable` и `Layout`; у встроенных — `trim`, углы `RoundedRectangle`, `offset`, `scale`, `rotation` фигур |
| Геометрия | `Path` (`forEach`, `addLines`, `addRects`, `addRelativeArc`, `strokedPath`, `trimmedPath`), `Shape.trim`, `Shape.size`, `Shape.sizeThatFits` (круг берёт меньшую сторону), `GeometryEffect` (переход слоя по `ProjectionTransform`, начало координат в левом верхнем углу, как у Apple), `ProjectionTransform` (`concatenating`, `inverted`, `isAffine`) |
| Анимация | `Animation`, `withAnimation`, `.animation` поверх `UIView.animate`, `transition`, `matchedGeometryEffect` с `@Namespace` (новый вид едет из места старого) |
| Core Data | `@FetchRequest` и `SectionedFetchRequest` поверх `NSFetchedResultsController` (перечитывание при сохранении контекста, изменение предиката и сортировки через `$request`), `FetchedResults`, `SectionedFetchResults`, `\.managedObjectContext` |
| Данные и события | `onAppear`, `onDisappear`, `onChange`, `onReceive`, `.id`, `tag`, `PreferenceKey` с `onPreferenceChange`, `transformPreference`, якоря (`Anchor`, `anchorPreference`, `transformAnchorPreference`, `GeometryProxy[anchor]`), `overlayPreferenceValue`/`backgroundPreferenceValue`, `@FocusState` с `.focused`, `Transaction`/`withTransaction`, `EquatableView` |
| Своё | `DynamicProperty` (свои обёртки свойств с вложенными `@State` и `update()`), `PreviewProvider` (собирается, в приложении не исполняется — как у Apple) |
| Мост к UIKit | `UIViewRepresentable`, `UIViewControllerRepresentable` с координатором и контекстом |
| Стили | `ButtonStyle` и `ToggleStyle` с настоящим `makeBody`; у `ButtonStyle` живое `isPressed` в конфигурации, у примитивных стилей нажатие приходит аргументом `makeBody(configuration:pressed:)` (см. ниже) (готовые `automatic`, `plain`, `bordered`, `borderedProminent`, `switch`, `button`), `TextFieldStyle`, `ListStyle` (plain/grouped/insetGrouped), `PickerStyle` (сегменты, колесо `UIPickerView` с `defaultWheelPickerItemHeight`, меню `UIActionSheet`, `.navigationLink` — строка с текущим значением, открывающая список выбора, `.inline` — варианты строками с галочкой), `LabelStyle`, `ProgressViewStyle`, `MenuStyle`, `DisclosureGroupStyle`, `GroupBoxStyle`, `LabeledContentStyle`, `ControlGroupStyle` (в том числе `.menu`), `GaugeStyle` (линейный и круговой `accessoryCircular`), `FormStyle` — все со своими `makeBody` и конфигурацией, `navigationViewStyle` (на iPhone любой стиль — стек, как и у Apple), `datePickerStyle(.wheel)` |
| Локализация | `LocalizedStringKey` ищет строку в бандле (`NSLocalizedString`), интерполяция подставляется как есть |
| Доступность | `accessibilityAdjustableAction` и `accessibilityScrollAction` (`accessibilityIncrement`/`Decrement`/`accessibilityScroll` у своего вида-обёртки), `accessibilityActivationPoint`, `accessibilityLabel`, `Value`, `Hint`, `Identifier`, `AddTraits`, `RemoveTraits`, `Element`, `Hidden`, `Heading` через `UIAccessibility` |
| Приложение | `App`, `Scene`, `WindowGroup`, `@main`, `UIHostingController` (с `sizingOptions`), живой `scenePhase` (`.active`/`.inactive`/`.background` от делегата приложения), `SceneStorage`, `Commands` и `.commands` (собираются; меню и клавиатурных команд в iOS 6 нет — пишет в журнал), `ToolbarContent` с `ToolbarContentBuilder` |

**Объявлены и игнорируются** — то, чему на iOS 6 нечему соответствовать. При первом применении каждый
печатает одну строку в журнал (`[SwiftUI] margins ignored on iOS 6: a margin takes the space around the view…`), список за прогон
доступен в `_Unsupported.used` (группа SPI `Probe`: `@_spi(Probe) import SwiftUI`) и печатается тестами:
`accessibilityActions`, `accessibilityChartDescriptor`, `accessibilityCustomContent`, `accessibilityIgnoresInvertColors`, `accessibilityInputLabels`,
`accessibilityLabeledPair`, `accessibilityLinkedGroup`, `accessibilityQuickAction`, `accessibilityRespondsToUserInteraction`, `accessibilityRotor`,
`accessibilityRotorEntry`, `accessibilityShowsLargeContentViewer`, `accessibilityTextContentType`, `blendMode`, `defaultFocus`,
`defersSystemGestures`, `digitalCrownAccessory`, `digitalCrownRotation`, `draggable`, `dropDestination`, `edgesIgnoringSafeArea`,
`exportsItemProviders`, `fileExporter`, `fileImporter`, `fileMover`, `findDisabled`, `findNavigator`, `flipsForRightToLeftLayoutDirection`,
`focusScope`, `focusSection`, `focusable`, `focusedObject`, `focusedSceneObject`, `focusedSceneValue`, `focusedValue`, `fontWidth`,
`handlesExternalEvents`, `horizontalRadioGroupLayout`, `hoverEffect`, `ignoresSafeArea`, `importableFromServices`, `importsItemProviders`,
`interactionActivityTrackingTag`, `interactiveDismissDisabled`, `itemProvider`, `keyboardShortcut`, `listRowPlatterColor`, `listSectionSeparator`,
`listSectionSeparatorTint`, `menuActionDismissBehavior`, `menuButtonStyle`, `menuIndicator`, `menuOrder`, `navigationBarTitleDisplayMode`,
`navigationDocument`, `onCommand`, `onContinueUserActivity`, `onContinuousHover`, `onCopyCommand`, `onCutCommand`, `onDeleteCommand`, `onDrag`,
`onDrop`, `onExitCommand`, `onHover`, `onLongTouchGesture`, `onMoveCommand`, `onPasteCommand`, `onPlayPauseCommand`, `pageCommand`,
`pasteDestination`, `persistentSystemOverlays`, `preferredColorScheme`, `prefersDefaultFocus`, `presentationBackgroundInteraction`,
`presentationCompactAdaptation`, `presentationContentInteraction`, `presentationCornerRadius`, `presentationDetents`, `presentationDragIndicator`,
`presentedWindowStyle`, `presentedWindowToolbarStyle`, `previewContext`, `previewDevice`, `previewDisplayName`, `previewInterfaceOrientation`,
`previewLayout`, `renameAction`, `replaceDisabled`, `speechAdjustedPitch`, `speechAlwaysIncludesPunctuation`, `speechAnnouncementsQueued`,
`speechSpellsOutCharacters`, `symbolRenderingMode`, `symbolVariant`, `textContentType`, `textSelection`, `toolbarRole`, `toolbarTitleMenu`,
`touchBar`, `touchBarCustomizationLabel`, `touchBarItemPresence`, `touchBarItemPrincipal`, `userActivity`

`accessibilityAction` (свои действия доступности появились в iOS 8; VoiceOver в iOS 6 делает двойное касание по самому виду), `Image(systemName:)` с именем вне набора (в iOS 6 нет SF Symbols; ~80 частых символов нарисованы встроенным набором `SymbolGlyphs`, для остальных имя ищется в бандле, затем рисуется квадрат со знаком вопроса), `swipeActions(edge: .leading)` (строка `UITableView` в iOS 6 свайпается только справа), `listRowSeparator(edges:)` и `listRowSeparatorTint(edges:)` (линия рисуется под строкой, а не над ней: таблица iOS 6 не рисует линии над строкой), `datePickerStyle(.compact)` и `datePickerStyle(.graphical)` (у `UIDatePicker` в iOS 6 есть только колесо).

Список закрытый: попасть в него может только то, чему на iOS 6 действительно нечему соответствовать,
и только вместе со строкой причины. Проверяется сборкой (`coverage.py --check`): если в исходниках появился
игнорируемый API без описания в этом разделе или счёт упал ниже `coverage-baseline.json`, сборка падает.

**Сделаны частично** — работает основной случай, остаток пишет в журнал `unimplemented` и попадает в отчёт прогона:
`navigationViewStyle(.columns)`, `NavigationSplitView`, `navigationSplitViewStyle`, `navigationSplitViewColumnWidth` и колонки `Table` на iPad (колонок `UISplitViewController` пока нет, показывается стек),
`matchedGeometryEffect(isSource: false)` (не-источник не подстраивается под источник).

**Упрощены** — работают, но с расхождением, которого iOS 6 не позволяет избежать; каждое пишет строку в журнал и
отчёт прогона при первом использовании: `Animation.spring` (и `interactiveSpring`, `interpolatingSpring`, `smooth`,
`snappy`, `bouncy`: у `UIView` iOS 6 нет пружинной анимации, поэтому свойство `UIView` идёт по ближайшей из
четырёх кривых времени; анимации самого движка, идущие кадр за кадром, считаются так же, как у Apple: `Animation.spring` и её именованные
формы — лесенкой шагов в 1/300 с, где конец определяют три проверки, а `interpolatingSpring` — решением пружины, которое
кончается там, где его кончает Core Animation; всё это сверено с macOS 27, `host/springcmp.swift`), `ShadowStyle.inner` (внутренних теней в CoreAnimation нет — не рисуется),
`Text.LineStyle.Pattern` (только сплошные подчёркивание и зачёркивание), `Font.leading` (вариантов интерлиньяжа у
`UIFont` нет — используйте `lineSpacing`), `Font.Design.rounded` (скруглённого системного шрифта нет — обычный),
`foregroundStyle(gradient)` у текста (текст одного цвета — первый цвет градиента), `submitLabel(.continue)`
(клавиши Continue нет — показывается Return), `scrollDismissesKeyboard` (на iOS 6 прокрутка клавиатуру не прячет;
с iOS 7 работает через `keyboardDismissMode`), `toolbarColorScheme(for: .tabBar)` (у `UITabBar` нет стиля панели),
`TextField(axis: .vertical)` (поле iOS 6 однострочное — текст прокручивается вбок), `Button(role: .destructive)` в `alert` (у `UIAlertView` iOS 6 нет стиля разрушающей кнопки — она выглядит как остальные; в `confirmationDialog` она красная), `ToolbarItemPlacement.keyboard` (у клавиатуры iOS 6 нет своей панели — элемент не показывается), `underline(color:)` и `strikethrough(color:)` (линия под текстом iOS 6 цвета текста), `copyable` и `cuttable` (лист `UIActionSheet`, а не меню правки: меню правки в iOS 6 принадлежит текстовому полю, и у вида, который не поле, своего меню нет), `listRowSeparator(edges:)` и `listRowSeparatorTint(edges:)` (линия рисуется под строкой, а не над ней: таблица iOS 6 не рисует линии над строкой, и просьба только про верхний край — это то, что и так есть), `grayscale`, `saturation`, `brightness`, `contrast`, `hueRotation`, `colorInvert`, `colorMultiply`, `luminanceToAlpha` (Core Image поверх картинки, в которую нарисован вид: картинка делается, когда экран раскладывает содержимое, поэтому анимация внутри отфильтрованного вида не идёт кадр за кадром), `blur(radius:)` (размывается собственный вид, а не то, что за ним: живого размытия фона в iOS 6 нет; при `opaque: false` картинка закрывает содержимое, иначе сквозь мягкие края просвечивало бы неразмытое), `dynamicTypeSize(range)` (диапазон ограничивает размер, которым рисуется текст поддерева; категория размера, которую читает вид внутри, остаётся запрошенной), `exportableToServices` (окно iOS 6 отдаёт то, чему дано, но у него нет завершения, так что приложение не узнаёт, что делиться случилось — это iOS 8), `presentationBackground(style)` (экран красится одним цветом, поэтому стиль, который не цвет, не красит ничего), `contentShape(kind)` (в iOS 6 нет превью перетаскивания и меню, ни эффекта наведения), `accessibility(inputLabels:)` (метки ввода — для Voice Control, которого в iOS 6 нет), `accessibility(selectionIdentifier:)` (идентификаторы выбора — для роторов, которых в iOS 6 нет), `toolbar(_:for: .tabBar)` (панель вкладок iOS 6 не скрыть для одного экрана), `Text.baselineOffset` (у атрибутированного текста iOS 6 нет смещения базовой линии — текст остаётся на ней), `Image(variableValue:)` (переменные символы — это SF Symbols, которых в iOS 6 нет; картинка рисуется целиком), `Font.smallCaps` (у шрифтов iOS 6 нет капителей — текст остаётся как есть), `Menu(primaryAction:)` (меню в iOS 6 открывается касанием, основное действие не выполняется), `searchable(tokens:)` (у поля поиска iOS 6 нет токенов — они показываются рядом фишек над полем), `listRowBackground(view)` (у строки UITableView за ней цвет; вид, не являющийся цветом, не рисуется), `RoundedCornerStyle.continuous` (непрерывной кривой скругления у пути iOS 6 нет — рисуется круговое), `ShapeStyle.blendMode` (режимов наложения слоёв в CoreAnimation iOS 6 нет — стиль рисуется обычным), `ShareLink(subject:)` (окно «Поделиться» iOS 6 не принимает тему), `commands` у сцены (в iOS 6 нет ни строки меню,
ни клавиатурных команд), `gesture(including:)` без `.subviews` (распознаватели iOS 6 нельзя выключить для всей
иерархии — жесты подвидов остаются включёнными; без `.gesture` жест просто не подключается). Приоритет жестов
устроен иначе, чем в SwiftUI: распознаватели предка и потомка срабатывают одновременно, а не «потомок побеждает»;
`highPriorityGesture` заставляет распознаватели потомков ждать распознавателя предка, `simultaneousGesture` не
отличается от `gesture`. `Layout.spacing` не читается родительским стеком: расстояния между видами задаёт
сам стек. Анимация `Animatable`-данных идёт так же, как у Apple, и это сверено на macOS 27 (см. «Замеры»): пружины, кривые
`UnitCurve` и `timingCurve`; `speed`, `delay`, `logicallyComplete`, `repeatCount` и `repeatForever` в любом порядке
вызовов; кастомная анимация, на которую вызваны `speed` или `delay`, получает пересчитанное время, не отдаёт скорость
и не сливается; смена цели, пока значение в пути, — вторая анимация-кривая или `interpolatingSpring` ведёт значение от того места,
куда первая его ещё несёт, к новой цели; вторая `Animation.spring` начинается от текущего значения со скоростью
предыдущей, если та тоже `Animation.spring`; без анимации первая идёт к своему концу, сдвинутому на разницу целей. Не сверено, и порт делает своё: пружина `Animation.spring`
с `delay` или `speed`, которой меняют цель в пути (ни одно правило не легло на замеры в пределах сотой — она стартует
от текущего значения без скорости); `repeatCount` дважды подряд (у Apple две пары повторов делят состояние и
ответы путаются, у нас действует последний); `shouldMerge` кастомной анимации при смене цели в пути (движок его не зовёт). `coverage.py --check` требует, чтобы каждая такая запись в коде была названа здесь.

`GeometryProxy.containerCornerInsets` отдаёт нулевые отступы: на iOS 6 ни один контейнер не рисуется со скруглёнными углами, скруглять нечего. У `LayoutSubview` и `LayoutSubviews` `==` объявлены явно, а у `GridItem`, `GridItem.Size`, `ScrollPosition` и `ScrollDismissesKeyboardMode` — через синтез компилятора: в отличие от `@frozen` типов Apple, наш модуль не печатает выведенные равенства в своём интерфейсе, и `bridge/api-diff.py` видит их как `__derived_struct_equals`.

`TabContent` повторяет объявление Apple 26.2 (`TabValue`, рекурсивное `Body`) без двух его внутренних членов: `_identifiedView` — внутренний член, который здесь никто не вызывает, а `_TabContentBodyAdaptor` существует только чтобы показать этот вызов; объявить их без потребителя было бы пустышкой. Инициализаторы `TabView` с `TabContent`-содержимым здесь не изолированы по `MainActor`, как у Apple: остальные инициализаторы `TabView` в модуле тоже не изолированы, иначе каждый вызов `TabView` требовал бы изолированного контекста.

`TableColumnCustomization<Value>` приходит в `Table(of:columnCustomization:columns:rows:)` и хранится в том, что читает таблица: `i`-й столбец — это столбец строки `order[i]`, и скрыта именно та строка, которую назвали, потому что у столбца здесь нет собственного идентификатора, только заголовок. Движок действует на `.visibility`: таблица iOS 6 это её собственный `UITableView`, и у него нет ни перетаскивания столбцов, ни их ширины, которой распоряжается приложение, так что `.reorder` и `.resize` — значения, которые приложение передаёт, а показать их негде. `TableColumnCustomization<Value>` кодируется одним значением, а не двумя полями: на этом runtime у keyed-контейнера нет типа ключа, а идентификаторы столбцов — это `Value.ID`, и он `Codable` там, где `Codable` сам `Value.ID`.

`PresentationDetent.custom(_:)` и `maxDetentValue` — высота, которую вычисляет приложение, и наибольшая деталь, которую позволяет платформа; у модального экрана iOS 6 нет деталей, он всегда во весь экран, поэтому `PresentationDetent.Context.maximum` — это экран, и `PresentationDetent.height(in:)` у `CustomPresentationDetent` возвращает то, что вычислило приложение, из этого контекста.

`ForEach(subviews:)` и `Group(subviews:)` берут детей через `subviewChildren(of:)`: так же, как движок читает детей везде, — через группу, за которую стоит обёртка, и через содержимое, которое обёртка оборачивает, пока не встретится то, что и есть содержимое. Расхождение с SwiftUI одно и оно названо здесь: свой `View`, чьё собственное `body` — это группа, здесь остаётся одним ребёнком, потому что у примитива нет тела, которое можно прочитать насквозь (его `body` — `Never` по построению), а в SwiftUI взяли бы детей группы.

Значения окружения, которых у iOS 6 нет как настройки (`accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `accessibilityShowButtonShapes`, `accessibilitySwitchControlEnabled`, `accessibilityQuickActionsEnabled`, `accessibilityLargeContentViewerEnabled`, `isLuminanceReduced`, `supportsMultipleWindows`), читаются как «выключено»: человек не мог их включить. `dynamicTypeSize` всегда `.large`. `monospacedDigit()` ничего не меняет: цифры системного шрифта iOS 6 и так одной ширины.

**Заглушек нет.** Последние четыре — доступность — сделаны на средствах iOS 6: `accessibilityRepresentation`
(метка, значение и черты элемента берутся из представления — кнопки, переключателя, ползунка, степпера, текста),
`accessibilityChildren` (вид становится `UIAccessibilityContainer`, дети раскладываются в его рамке и отдаются как
`UIAccessibilityElement`), `accessibilitySortPriority` (корневой вид хоста — контейнер, который при заданных
приоритетах упорядочивает элементы по приоритету, затем по положению на экране), `accessibilityFocused` (привязка
переводит фокус VoiceOver уведомлением `UIAccessibilityLayoutChangedNotification` с элементом, а фокус VoiceOver
пишет привязку через `accessibilityElementDidBecomeFocused`/`DidLoseFocus`). Имя каждой будущей заглушки счётчик
читает из вызова; вызов, имени которого он прочесть не может, валит сборку — так заглушка не спрячется от счёта.

**Нет вовсе** — таких API в модуле нет, приложение с ними не соберётся: лучше ошибка компиляции, чем тихо
неправильный экран. Это `NavigationStack(path:)`
(`NavigationStack` есть как стек без пути), и типы из списка `coverage.py --missing`, не попавшие ни в одну из групп выше.

## Две сборки модуля

- **Нативная** (приложение компилируется из исходников под armv7 iOS 6) — без библиотечной эволюции.
- **Гостевая** (для конвейера рекомпилятора: модуль собирается под arm64 и переводится вместе с приложением) —
  с `-enable-library-evolution`, иначе компилятор не выпускает method descriptors протоколов, которых
  требует приложение, собранное против интерфейса Apple.
  `bridge/guest-abi-check.sh` (removed, 2026-10-06) checked this build and did not check the release the port ships:
  it compiled with /usr/bin/swiftc 6.4 for arm64-apple-ios14.0 against the iOS 16.4 SDK, whose Swift 5.9 stdlib has no
  `RangeSet`, so it failed on `TextSelection` (`cannot find type 'RangeSet'`); the port ships armv7-apple-ios6.0 on the
  swift-runtime package, whose stdlib has it. Measured: every installed swift-runtime (6.4.0, six store entries) holds
  only `armv7-apple-ios.swiftmodule`; an arm64 library_evolution install (`xmake f -p iphoneos -a arm64`) fails in
  charon@libcxx ("the probe client does not import __ZdlPv"; the cause was not
  diagnosed further, and the recipe is charon's). When an arm64 runtime
  installs, rebuild the check against `-resource-dir <runtime>/lib/swift`, not the SDK's stdlib.

Из этого следуют требования к коду: модуль называется `SwiftUI`, имена и метки аргументов совпадают
с Apple дословно, порядок требований протоколов — слот в слот (таблица в `../bridge/README.md`),
публичные классы хранят только свойства статически известного размера.

## Устройство

- `Sources/SwiftUI/Core.swift` — протокол `View`, построитель, прозрачные контейнеры.
- `Sources/SwiftUI/Graph.swift` — дерево узлов, согласование, транзакции обновления, вписывание динамических свойств по смещениям полей из метаданных Swift.
- `Sources/SwiftUI/State.swift` — обёртки свойств и их хранилища в узлах.
- `Sources/SwiftUI/Layout.swift` — модель раскладки, стеки, `Spacer`, `padding`, `frame`.
- `Sources/SwiftUI/Views.swift` — примитивные представления поверх контролов UIKit.
- `Sources/SwiftUI/Modifiers.swift` — модификаторы как узлы и как изменение окружения.
- `Sources/SwiftUI/List.swift`, `Navigation.swift` — `UITableView` и `UINavigationController`.
- `Sources/SwiftUI/Presentation.swift` — лист и предупреждение, `Sources/SwiftUI/Environment.swift` — ключи окружения.
- `Sources/SwiftUI/Hosting.swift` — контроллер-хост, `Sources/SwiftUI/App.swift` — запуск приложения.
- `Sources/SwiftUI/Probe.swift` — служебный доступ для тестов (дерево, размеры строк, число вычислений `body`).

## Сборка и проверка

```
./build.sh                       # модуль SwiftUI, EidolonDemo.app, EidolonTests, EidolonProbe (armv7, iOS 6)
../run-emu.sh t1 out/EidolonDemo.app EidolonTests          # модульные тесты движка в iLEmu
../snapshots.sh [--accept]                          # снимочные тесты: деревья сценариев против Snapshots/reference
../run-app.sh app1 out/EidolonDemo.app 560 ../scratch/ctl7.txt   # демо в эмуляторе со сценарием касаний
```

Сборка идёт против установки пакета `charon@swift-runtime` 6.4.0, которую требует `../rtpkg`, в общем хранилище
xmake; `../pkg-env.sh` спрашивает путь к каждому пакету у самого xmake (`xmake where`) и собирает флаги.
Все модули и dylib — из одной установки: стандартная библиотека, конкурентность, оверлеи Foundation, UIKit,
QuartzCore, CoreGraphics, Dispatch, ObjectiveC, CoreFoundation и CoreData. Цель — `armv7-apple-ios6.0` с
`-bundled-swift-runtime`, **проверка доступности включена**: любое API новее iOS 6 компилятор называет сам, а не
падение на устройстве (так нашлись и исправлены `CGPathAddRoundedRect`, `component(_:from:)`,
`keyboardDismissMode`, `contentSizeForViewInPopover`; `NSItemProvider`/`NSUserActivity` в подписях помечены iOS 8).
Combine — пакет `charon@styx` 2026.09.20 (форк OpenCombine, модуль `Combine`) из той же установки, собранный против того же
рантайма: без издателей `URLSession` (iOS 7), допуск таймера — за `#available`; `../rtpkg` требует его с тем же
рантаймом. Прогон тестов предка, OpenCombine, — `../combine/build.sh pkg` (1448 из 1453); у Styx свои тесты.

## Замеры

- Модульные тесты движка: 338 проверок (раскладка, выравнивания, сетка, состояние, наблюдаемые объекты, окружение,
  списки, их правка и выбор, секции, `ZStack`, `ScrollView`, идентичность в `ForEach`, стили, жесты и их формы,
  пространства координат, переходы, `matchedGeometryEffect`, предпочтения и якоря, градиенты по пикселям,
  `Canvas`, `@FetchRequest` с живым обновлением из Core Data, доступность), iLEmu iPhone4,1 iOS 6.1.3 и живой
  iPad 2 (iOS 6.1.3) — все проходят.
- Снимочные сценарии в приложении (iPod4,1 iOS 6.0): 16 деревьев, сверяются посимвольно с эталонами в
  `Snapshots/reference`; эталон нового сценария записывается только после ручной проверки дерева.
- Производительность (безоконный пробник `EidolonProbe`, живое железо iOS 6.1.3; `../device-run/`): простой экран —
  полное обновление 1,6 мс на iPad 2 и 2,1 мс на iPhone 4S, первичная сборка и раскладка 6,5 мс. Глубокий экран —
  шесть строк вложенных стеков глубины d — до кэша размеров рос в 7–8 раз на уровень (d=3: 1174 мс на обновление,
  d=6 не дождались за 15 минут), с кэшем растёт линейно: d=1 — 14 мс, d=3 — 56 мс, d=6 — 139 мс (iPad 2). На iPhone 4S (те же сборка и сценарий, финальная версия): d=1 — 19 мс, d=3 — 78 мс, d=5 — 139 мс; обновление одной строки из шести — 4,9 / 15 / 25 мс. Кэш:
  у каждого узла раскладки до 32 ответов «предложение → размер»; сбрасывается при обновлении узла, у его
  вложенных узлов раскладки и у всех предков. Синхронизация подвидов (`mountContents()`) и применение кадра
  (`place()`) дополнительно пропускаются для узла, чей кадр не изменился и который не был помечен грязным —
  когда меняется только одна строка из шести, обновление на iPad 2 падает: d=1 — 3,4 мс, d=3 — 10 мс, d=5 — 18 мс.
  Текст (внутри приложения, `perf.sh`; вне приложения на устройстве нет шрифтового сервера, процесс падает на
  первом `Text`) идёт немного дороже цвета на глубоких экранах из-за измерения строк, но растёт так же линейно.

- `Spring` и `UnitCurve` сверены с фреймворком macOS 27 (`.agent-work/host/` — снимок замеров и хост-проверка): совпадают до девятого
  знака `value`/`force`/`update` для всех четырёх способов построить пружину, все семь её свойств
  (`response`, `dampingRatio`, `duration`, `bounce`, `mass`, `stiffness`, `damping`), значения и скорости трёх
  круговых кривых, и `settlingDuration` во всех
  формах: у колеблющейся пружины это огибающая размаха, ниже `epsilon` (логарифм, делённый на затухание), у остальных —
  десятая доля секунды после последней десятой, где расстояние ещё не меньше `epsilon`; сетка у Apple 1013 десятых
  (до 101,2 с), и если на последней пружина ещё снаружи, Apple отвечает «успокоилась сразу» (0) — граница найдена
  делением отрезка по отклику и жёсткости (`host/springcmp.swift`), а у критической интерполирующей пружины то же с 1012
  десятыми. Расходятся в двух местах, и оба измерены:
  Безье-кривые — на 5·10⁻⁷ (наш корень точнее: у Apple он одинарной точности, `0.399999619` против `0.4` —
  это `Float`); `velocity` перезатухающей пружины (`dampingRatio > 1`)
  — у Apple она не является производной его же `value` (при `dampingRatio` 1.25, `response` 1, t=0.1 Apple отвечает
  2.867334, производная равна 1.867334), у нас — производная, иначе `update(value:velocity:target:deltaTime:)` врал бы.
  Совпадают и края: `bounce` ниже −1 (у Apple и у нас `nan`), `bounce` выше 1 (пружина без затухания, время
  установления бесконечно), `response` 0, `epsilon` 0, `allowOverDamping` (у Apple жёсткость перезатухающей пружины
  пересчитывается так, чтобы отношение осталось заданным, — так же и у нас). `Spring.mass`, `Spring.stiffness` и
  `Spring.damping` у нас только для чтения: у Apple их можно присвоить, но присваивание выбирает, из какой формы
  пружина собрана, а её модель на это не отвечает. `Animation.spring()` без аргументов берёт `response` 0.5 — как в
  SDK 26.2; в 16.4 было 0.55.

- `KeyframeAnimator` и `PhaseAnimator` считаются на тех же средствах, что и остальная анимация движка: `ValueAnimator`
  ведёт значение кадр за кадром по развёрнутой дорожке (`_ResolvedKeyframes`) — каждый ключевой кадр идёт от значения перед
  ним к своему по своей кривой, — а узел перестраивает содержимое на каждом кадре. Виртуальные часы пробника
  (`_Probe.advanceAnimations`) ведут их так же, как и остальные анимации. `AnimationCompletionCriteria.removed` совпадает
  с `.logicallyComplete`: в движке нет интерактивного увода, и вид, который убирают, заканчивает анимацию в тот же момент.
- `EnvironmentValues` читает и хранит `tintColor`/`accentColor` (движок красит им строку состояния и кнопки меню),
  `symbolRenderingMode`, `symbolVariants`, `textContentType` (у iOS 6 типов содержимого текста нет — остаётся nil),
  `isFocused`, `isHoverEffectEnabled` (палец не может навести, поэтому всегда выключено), `listRowSpacing`,
  `listSectionSpacing` и `description`. `Anchor.Source` умеет собирать массив якорей и якорь необязательного значения, а
  `Anchor` сравнивается и хешируется по виду, на который указывает, и по значению, которое читает из единичного
  прямоугольника. `verticalScrollIndicatorVisibility`, `horizontalScrollIndicatorVisibility`,
  `verticalScrollBounceBehavior` и `horizontalScrollBounceBehavior` читает полоса прокрутки (`ScrollNode.update`):
  видимость индикатора берётся из окружения, а `.automatic` оставляет решение флагу вида (`scrollIndicators(_:axes:)`);
  отдача — `alwaysBounceVertical`/`alwaysBounceHorizontal` `UIScrollView`, `.automatic` оставляет её как есть.
- `EnvironmentValues` несёт и остальные 78 ключей SDK 26.2: у каждого тип, какой объявляет интерфейс Apple, и
  значение по умолчанию — снято с фреймворка macOS 27 (`.agent-work/host/envdefaults.txt`, 64 ключа читаются
  публично; остальные берут значение из тел Apple's собственных расширений или то, что человек на iOS 6 включить
  не мог). Ключ — это хранилище: значение читают виды и пишут модификаторы, независимо от того, читает ли его
  сегодня хоть один вид. Значения, названные типами, которых у этого порта нет, объявлены рядом
  (`EnvironmentValueTypes.swift`) по списку случаев из интерфейса Apple.
  Не объявлены 18: `immersiveSpaceDisplacement` (тип `Spatial.Pose3D` — Spatial не фреймворк iOS),
  `openImmersiveSpace` и `dismissImmersiveSpace` (immersive space — виvisionOS), `allowedDynamicRange`
  (запас яркости выше SDR у экранов iOS 6 нет), `openWindow`, `pushWindow`, `dismissWindow`, `openSettings`,
  `newDocument`, `openDocument` и `rename` (окон и документов в iOS 6 нет), `realHorizontalSizeClass` и
  `realVerticalSizeClass` (классы размера Catalyst), `defaultWheelPickerItemHeight` (колесо выбора — watchOS),
  `isSceneCaptured`, `fontResolutionContext` (`Font.Context` — тип SwiftUI iOS 18, вложенного `Context` у нашего
  `Font` нет), `lineHeight` и `_lineHeightMultiple` (это свойства `AttributedString`, которого в этом заходе
  ещё нет). Для них — `bridge/not-applicable.txt` (16 строк); `lineHeight` и `_lineHeightMultiple` ждут `AttributedString`.

- `TypesettingLanguage.contentAware` — внутренний: вверх по потоку он за `@_spi(Private)`, а у Apple в 16.4
  и 26.2 такого члена нет вовсе (`SwiftUICore.swiftinterface:8758-8762` — только `automatic`,
  `explicit(_:)` и `==`).
- `blur` и шесть цветовых фильтров получают измеренную формулировку: размытие в каноне этого порта есть
  (`apple-backports/UIKit/UIVisualEffect.m`, `CharonBlur.m`; `facts/UIKit/UIVisualEffect.md`), но это
  `UIView`, а у модификатора SwiftUI нет вида, в который его положить; шесть фильтров ложатся на
  `compositingFilter` слоя, который порт уже ставит, и пока им не рисуется.
- `SymbolVariants` взят из OpenSwiftUI (MIT, `OpenSwiftUIProject/OpenSwiftUI`,
  `Sources/OpenSwiftUICore/View/Image/SymbolVariants.swift`, коммит `efa1037`): вариант символа с его
  флагами (`none`, `fill`, `slash`, `circle`, `square`, `rectangle`), их сочетаниями, `contains(_:)` и
  модификатором `symbolVariant(_:)`, который пишет вариант в окружение. Наш прежний — заглушка из трёх
  имён без вариантов. SF Symbols в iOS 6 нет, поэтому вариант пишется в окружение, а картинка ищется по
  имени со суффиксом варианта тем же встроенным набором, что и раньше.
- `ResolvedText` и дерево `Resolvable*` (решающие значения `Text`: `timer`, `date`, `relative`, `offset`,
  `progress`, `currentDate`, интервал) в OpenSwiftUI тоже есть, но они опираются на `AttributeGraph` и
  на `Environment` этого движка — переносить их к iOS 6 нечего, пока не будет решено, чем заменяется граф.
  `ParagraphTypesetting` (насколько абзац сжимается, где переносится) — тоже, и он опирается на тот же граф.

- Настройки текста, которые добавил SDK 26.2. `TypesettingLanguage` и `Text.Scale` взяты из OpenSwiftUI
  (MIT, `Sources/OpenSwiftUICore/View/Text/Typesetting/TypesettingLanguage.swift` и
  `Sources/OpenSwiftUICore/View/Text/Text/Text+Scale.swift`, оба «Status: Complete», коммит `efa1037`):
  `automatic`/`explicit(_:)`, `.default`/`.secondary` и `textScale` в окружении. Модификаторы объявлены и
  на `Text`, и на `View` — как их и объявляет интерфейс 26.2: `typesettingLanguage` (одним шрифтом iOS 6
  настройки нет), `textScale` и `textVariant` (вариантов размера и ширины у текста iOS 6 нет;
  `textVariant` — над `TextVariantPreference`, с `FixedTextVariant` и `SizeDependentTextVariant`), плюс
  `textScale(.secondary)` рисует строку размером меньшей надписи самого релиза: caption 1 против body,
  12/17 — из `apple-backports/facts/UIKit/UIFontTextStyles.md:18,20`; `writingDirection(strategy:)` и
  `multilineTextAlignment(strategy:)` с их тремя случаями — обе
  стратегии пишут в журнал, обе названы там же. `writingDirection` и `multilineTextAlignment` —
  имена этих двух модификаторов в журнале. И четыре речи
  VoiceOver — `speechAlwaysIncludesPunctuation`, `speechSpellsOutCharacters`, `speechAdjustedPitch`,
  `speechAnnouncementsQueued`. Сами четыре атрибута в каноне этого порта есть
  (`apple-backports/UIKit/UIAccessibilitySpeechAttributes.m` и два соседа, `registry/UIKit/ios13rest.json`),
  а VoiceOver iOS 6 не читает ни одного с атрибутированной строки —
  `apple-backports/facts/UIKit/UIAccessibilitySpeechAttributes.md`; каждый пишет в журнал именно с этим.
  Эти четыре `Text`-перегрузки — то, что добавил 26.2; `View`-перегрузки были уже в 16.4.
  `TypesettingLanguage` назван по идентификатору языка: в Foundation этой поры нет `Locale.Language`.
- `PlainButtonStyle`, `BorderedButtonStyle`, `BorderedProminentButtonStyle`, `DefaultButtonStyle` и
  `BorderlessButtonStyle` — это `PrimitiveButtonStyle`, а не `ButtonStyle`, как в обоих SDK, которые у нас
  есть (в 16.4 и в 26.2 у `ButtonStyle` нет ни одного `where Self ==`-расширения, а эти шесть стилей объявлены
  как `PrimitiveButtonStyle`); наши пять имён `ButtonStyle.plain` и подобных выдуманы и убраны.

- `bridge/tools/` держит то, чем этот диапазон меряет свою полноту: `ours.py` читает, что объявляет
  дерево, `gaps.py` говорит, чего из поверхности 26.2 в этом дереве нет, `ours-check.py` сторожит оба.
  Числа, которые этот диапазон приводил до сих пор, — **нижняя граница**: `count('{')` по строке ломался на
  любой строке, где скобка стоит в строке или в комментарии, и с неё обход уходил на неверную глубину.
  Теперь скобки считает `braces()`, который читает строку как Swift: `//`, `/* */`, `"…"`, многострочный
  литерал и `#"…"#` скобку не несут, а блок-комментарий и многострочный литерал состояние переносят.
  Семь контролей в `ours-check.py` это сторожат, включая тот, что требовал от `ours.py` самого: расширение
  `Anchor.Source` в `TextModifiers.swift:168` даёт `bounds` и `rect`. Пересчёт после этого даёт те же 169
  строк, и это тоже честно: `Anchor` остаётся шестнадцатью, потому что расходятся не обходы, а то, кому
  принадлежит член, — `surface-26.2.tsv` относит член расширения `Anchor.Source` к `Anchor`, а `ours.py`
  хранит последнюю компоненту имени. Это дефект второй инструменты, а не этого, и он назван ниже.

- Стили кнопки. `link` (синее подчёркнутое слово, как ссылка в `UITableViewCell` iOS 6) и `card`
  (скруглённая кнопка релиза без градиентной заливки) есть и в 16.4, и в 26.2 — их не хватало у нас.
  Добавляет 26.2:
  `PrimitiveButtonStyle.glass` и `PrimitiveButtonStyle.glassProminent` (живого размытия в iOS 6 нет — кнопка
  рисуется полупрозрачной, пишет в журнал), `PrimitiveButtonStyle.accessoryBar` и
  `PrimitiveButtonStyle.accessoryBarAction` (панели над клавиатурой в iOS 6 нет — рисуется кнопка релиза, пишет в журнал),
  `Glass` (толщина стекла — это то, чем заливается полупрозрачная заливка), `ButtonRole.confirm` и `.close`.
- Нажатие кнопки. `PrimitiveButtonStyleConfiguration` такого члена не имеет ни в 16.4, ни в 26.2, и мы его
  не добавляем; `@Environment(\.isPressed)` в стиле тоже не сработал бы — стиль попадает в замыкание, мимо
  которого реконсилятор не проходит. Поэтому узел кнопки хранит тело примитивного стиля рядом с телом
  `ButtonStyle`, обработчик нажатия работает на обоих путях (раньше он выходил по `styleBody != nil`, то
  есть ровно на примитивном), а нажатие приходит стилю аргументом: наш собственный протокол
  `PressedButtonStyle` и `makeBody(configuration:pressed:)` у встроенных стилей, при этом запись
  `makeBody(configuration:)` — как у Apple — тоже компилируется и даёт то же тело. Проверка в тестах
  движка нажимает `.plain` и читает дерево обратно: тело, нарисованное при нажатии, отличается от
  нарисованного до, и совпадает с тем, что стиль просил (`opacity 0.4`).
  `EnvironmentValues.isPressed` остаётся ключом с владельцем и без читателя в наших стилях: его читает
  путь `ButtonStyleConfiguration`, который сам пишет его в окружение содержимого. Стиль, написанный
  приложением, нажатия не увидит — на то и внутренний протокол; Apple даёт его через окружение, а
  окружение стиля здесь не разрешается.
- Стили `DatePicker` получили форму: `DatePickerStyle` требует `_body(configuration:)`, у конфигурации есть отметка,
  выбор, границы и показываемые компоненты. `.field` рисует дату в рамке, как ячейка сгруппированной таблицы iOS 6,
  а `.stepperField` — то же поле с двумя `UIStepper` по краям, которые идут по дате на сутки или на час.
  Требование протокола — `makeBody(configuration:)`, как у Apple; `_body(configuration:)` есть, но по
  умолчанию отдаёт `EmptyView`, и движок зовёт `makeBody`. Отметка показа везде на месте: над колесом у
  `.wheel`, рядом с полем у `.field` и между полем и степперами у `.stepperField` (сценарий
  `date-picker-styles`). `DatePickerStyle.compact` и `DatePickerStyle.graphical` пишут в журнал: `UIDatePicker` в iOS 6 умеет только колесо, поэтому колесо и остаётся.

- Обратная проверка поверхности, `bridge/api-surface.sh` со `STRICT=1`, читает объединение интерфейсов
  26.2 всех модулей, которые этот переэкспортирует, и печатает каждое наше публичное имя, которого там нет.
  После этого захода в её списке 241 строка, и ни одна не выдумана этим заходом: 200 — из базовой ветки
  (`_Probe` 34, `ColorMatrix` 16, `_DialogDescription` 6, `GestureEvent` 6, `ProjectionTransform` 6 и
  прочие — до обоих заходов), а остальные 41 — из двух классов, которые ревью уже назвало артефактами
  инструмента: 55 вложенных `typealias` вида `GlassButtonStyle.Configuration`, которые порт обязан
  объявить, а интерфейс Apple их не расписывает, и 7 `Body`-свидетельств ассоциированных типов. Пятьдесят
  восемь строк, которые добавил этот диапазон, убраны: четыре имени из ревью плюс хранилища ключевых
  кадров. Интерфейсы 26.2 теперь читает `bridge/tools/surftool` — `SwiftParser` из swift-syntax
  (Apache-2.0, подключён путём, ничего не вендорится) вместо регулярных выражений: 40 из 41 строки
  артефактов уходят, остаётся 205, а добавляются четыре — `CGAffineTransform`, `CGPoint`, `CGRect` и
  `CGSize`, которые выражения принимали за объявленные, хотя их нет ни в одном интерфейсе девяти
  переэкспортируемых модулей. Счёт в обеих строках один и тот же — 0: `invented.txt` содержит только
  выдуманные имена, а разрешённые уходят в stderr, так что и файл на пустом дереве пуст, и `STRICT=1` проверяет
  ровно то, что напечатано.

- Атрибуты SwiftUI объявлены в той форме, в какой их объявляет интерфейс 26.2, но без конформленсов
  `AttributeScope` и `AttributedStringKey`: `import Foundation` в iOS 6 не знает ни `AttributedString`, ни
  `AttributeScope`, ни `AttributeScopes`, и объявить их в форме Apple нельзя вовсе — поэтому объявлено то, что релиз
  может исполнить: атрибут, чьё имя и чей тип значения совпадают с Apple, и ключ `NSAttributedString`, под который он
  пишется. Значение, дошедшее до нарисованной строки, здесь не проверяется: чтение такой строки требует создать шрифт,
  а шрифт роняет headless-процесс на устройстве (измерено: EidolonTests падает с `Trace/BPT trap` на первом же
  создании `UIFont`), поэтому проверены имена, типы значений и соответствие ключу — по одному случаю на атрибут.

- `TextSelection` — по форме 26.2 (`SwiftUI.swiftinterface:20146`): `Indices` с двумя случаями
  `selection(Range<String.Index>)` и `multiSelection(RangeSet<String.Index>)`, `affinity`, три
  инициализатора и `isInsertion`. `EnvironmentValues.textSelection` читает и пишет выбор, а узел
  `TextEditor` отдаёт его своему `UITextView`: iOS 6 несёт ровно один выделенный диапазон, поэтому
  набор диапазонов читается и записывается как самый нижний из них, и об этом сказано в коде.
  `nsRange(in:)` и `init(nsRange:in:)` — наш мост к `UITextView`, внутренние: это не API 26.2. Замер —
  в `docs/facts/TextSelection.md`: сам заголовок UIKit 26.2 говорит, что `selectedRange` — это весь
  выбор начиная с iOS 2, а первый `NSArray` выделенных диапазонов — `selectedRanges` в iOS 26.0.

- `RasterizationOptions` — вложенный, как в обоих SDK: `_RendererConfiguration.RasterizationOptions`
  (`arm64e-apple-ios.swiftinterface:17490` и в 26.2 то же), семь хранимых свойств и `init()`. Значений по
  умолчанию **ни один интерфейс не даёт**, и на хосте его не прочитать: тип член underscored-структуры и на
  публичной поверхности macOS его нет — **это было неверно**: подчёркнутое имя в Swift публичное, и
  `eidolon/host/hostrenderer.swift` его читает. Замерено на фреймворке macOS 27: `colorMode` nonLinear,
  `rendersAsynchronously` false, `isOpaque` **true**, `drawsPlatformViews` **true**,
  `prefersDisplayCompositing` false, `maxDrawableCount` **3**, `rbColorMode` nil. Внешний тип назван так,
  как его объявляет SDK, — `_RendererConfiguration`, без замены. В слой `CALayer` iOS 6 доходят три из семи:
  рисовать ли в главном потоке, непрозрачен ли слой и масштаб растеризации.
  Каждое из них — то, что у `CALayer` iOS 6 есть: асинхронная отрисовка и масштаб растеризации едут в слой,
  а `colorMode`, `rbColorMode`, `drawsPlatformViews`, `prefersDisplayCompositing`, `maxDrawableCount` и
  `isOpaque` — ключей, которых у слоя нет, и они остаются на порте. `drawingGroup` собирает эти значения
  и отдаёт слою те два, что у него есть. Сам `applied(to:)` — наш, и он внутренний. Ключа в
  `EnvironmentValues` нет: `RasterizationOptions` у Apple — параметр тех API, которые его берут, и ни в
  16.4, ни в 26.2 такого ключа нет; обратная проверка это и показала, когда первая версия файла его
  объявила.

- Виджеты: `Widget`, `WidgetConfiguration` и `WidgetBundle` — три протокола, как в интерфейсе 16.4
  (`:19488`, `:12988`, `:11775`, все `@available(iOS 14.0, macOS 11.0, watchOS 9.0, *)` и
  `@available(tvOS, unavailable)`), плюс `EmptyWidgetConfiguration` и два настоящих сборщика —
  `WidgetConfigurationBuilder` и `WidgetBundleBuilder` с теми же шестью функциями, что у Apple. На iOS
  6.1.3 виджета нет: системной площадки для него у релиза нет, поэтому виджет здесь никогда не
  показывается — ровно как в приложении без виджет-расширения; протоколы и тело мы носим, площадку — нет.
  `WidgetConfigurationBuilder` в интерфейсе нет вовсе (`grep -c 'struct WidgetConfigurationBuilder'`
  — 0 и в 16.4, и в 26.2), и ни `Widget.body`, ни `WidgetConfiguration.body` не несут сборщика — только
  `WidgetBundle.body` несёт `@WidgetBundleBuilder`. Наш сборщик — ровно шесть функций интерфейса
  (`arm64e-apple-ios.swiftinterface:7114-7142`): `buildExpression`, `buildBlock()`, `buildBlock(_:)`,
  `buildOptional` в двух формах и `buildLimitedAvailability`; подпись последней взята из интерфейса —
  `(_ widget: some Widget) -> any Widget & _LimitedAvailabilityWidgetMarker`, — и `_LimitedAvailabilityWidgetMarker`
  публичен, потому что публичная функция не может назвать внутренний тип. `WidgetBox`, `AnyWidget` и
  `AnyLimitedAvailabilityWidget` — наши и внутренние: existential не отвечает `Widget` сам по себе.

- `Window`, `OpenWindowAction` и `PresentedWindowContent`. `Window` — сцена, и Apple объявляет её только для
  macOS: четыре аннотации на типе в `arm64e-apple-ios.swiftinterface:2740-2743` —
  `@available(macOS 13.0, *)`, `@available(iOS, unavailable)`, `@available(tvOS, unavailable)`,
  `@available(watchOS, unavailable)`. Носим потому, что сцена — это корень движка, поверх единственного
  `UIWindow` iOS 6. `OpenWindowAction` помечен `@available(iOS 16.0, macOS 13.0, *)` с
  `@available(tvOS, unavailable)`, `@available(watchOS, unavailable)` (там же, :8191-8197), и ни один его
  член не помечен недоступным на iOS — а `Window`, который он открывает, macOS-only в том же файле. На этом
  и стоит ответ: на iOS есть действие и одно окно, так что открывать нечего — действие пишет в журнал.
  `Window.presentedWindowContent(forPresented:)` отдаёт `PresentedWindowContent` с тем же содержимым, и
  тоже пишет в журнал, потому что предъявленного окна на iOS 6 нет. Документации Apple в
  сгенерированном интерфейсе нет — комментариев он не несёт, — и опора здесь именно на эти аннотации.
  Имена в журнале: `Window.presentedWindowContent(forPresented:)`, `OpenWindowAction(id:)` и
  `OpenWindowAction(value:)` — последнее потому, что iOS 6 и не передаёт окну значение.

- Две проверки на iPad 2 оказались не проверками, а моими утверждениями о том, чего API не обещает.
  `EnvironmentValues.tint` — хранимое `var tint: UIColor?` без значения по умолчанию, и пишут его четыре
  модификатора (`ListExtras.swift:461`, `MoreTypes.swift:134`, `TextExtras.swift:139`,
  `Toolbars.swift:253`), ни один при импорте; проверка же обходила дерево и спрашивала, есть ли хоть где
  фон не `.clear`, то есть отвечала на другой вопрос. Теперь вид записывает, что прочитал, и проверяется
  оно. `SymbolVariants.contains` — включение в множество (`flags.contains(other.flags) && (shape == other.shape
  || other.shape == nil)`, `SymbolVariants.swift:355`): пустое множество — подмножество любого, поэтому
  `fill.contains(.none)` истинно, и так же оно и у Apple; проверка читала включение как тождество. Теперь
  тождество и включение проверяются отдельно, обе стороны равенства записаны.

- Проверка на «виджет-бандл безусловно не собирается» лежит в `eidolon/tools/tabletests/`: `if` без
  `#available` доходит до проверки типов как `any Widget`, а existential не отвечает `Widget`, и сборка
  отказана. Недоступной перегрузки `buildOptional` в интерфейсе 26.2 нет вовсе: у `WidgetBundleBuilder` есть
  две формы (`arm64e-apple-ios.swiftinterface:21949` и `:21970`), обе доступные, и ни одна не берёт такой
  `if`. Сама недоступная — `extension WidgetBundleBuilder : Sendable` (`:21942-21943`), и она помечена так
  же, как у нас. **Мутант, который различает, — обратный тому, что был проверен сначала:** не убирать
  перегрузку, а добавить
  `static func buildOptional(_ widget: (any Widget)?) -> some Widget`. С ней проверка компилируется, и
  `tabletests/run.sh` выходит с 1: `negative-widget-bundle: FAIL -- expected a rejection naming cannot
  conform to 'Widget', got: it compiled`; без неё — выход 0 и отказ. Оба прогона в
  `eidolon/host/runs/`. То есть проверка сторожит ровно то, что сторожит форма SDK, и может стать красной.

- Десять типов, доступных на iOS, которые мы **не носим**, и по какой причине каждая. Проверено по
  интерфейсу 26.2 (`iPhoneOS26.2.sdk/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface`
  и `…/WidgetKit.swiftmodule/…`), а не по догадке:
  - `ContentOffset` (`:11480`) — внутри `extension SwiftUI._ScrollViewGestureProvider`, подчёркнутое;
  - `Direction` (`:11595`) — сам интерфейс пишет его как `_PagingViewConfig.Direction`, тоже подчёркнутое;
  - `Tree` (`:6541`) — `Root: SwiftUICore._VariadicView_Root`, ограничение на подчёркнутое;
  - `Cache` (`:18090`) — внутри `extension SwiftUI.GridLayout`, а разметку ведёт другая полоса;
  - `TypedPayloadError` (`:17049`) — интерфейс пишет его `Foundation.NSUserActivity.TypedPayloadError`,
    то есть это тип Foundation, а не SwiftUI;
  - `Data` (`:11125`) — `public typealias Data = Content.Data`, вложенный, а не имя уровня модуля;
  - `UIHostingConfiguration` (`:10542`) — публичный и на iOS, но `UIKit.UIContentConfiguration` есть с
    iOS 14, а порт собирает под iOS 6: отвечать протоколу, которого у платформы нет, нельзя;
  - `SwiftUIAttributes` (`:7696`) — то же с `Foundation.AttributeScope` (iOS 15);
  - `AligningContentProviderLayout` (`:11541`) — публичный, без аннотаций, но это `Layout`, а
    раскладки ведёт другая полоса;
  - `Property` — это `_ViewDebug.Property`, член подчёркнутой структуры, то есть отладочная машинерия
    (`SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface:14901`, внутри `public enum _ViewDebug`; в
    интерфейсе SwiftUI его нет, там только `SwiftUICore._ViewDebug.Data` в `:21897` как тип возврата);
  - `Renderer` — вложен в `_RendererConfiguration` (`:14472`) и **носится** вложенным, в
    `Rasterizations.swift`, вместе с `RasterizationOptions` и `BackgroundTask`;
  - `LimitedAvailabilityConfiguration` (`:9248`) — **носится**, см. выше.
  Из четырнадцати носимых три: `Renderer`, `BackgroundTask`, `LimitedAvailabilityConfiguration`, и
  `Property` в списке — десятый неперенесённый.

- Дорожка ключевых кадров — наше чтение, а не 26.2: в `SwiftUICore.swiftinterface:5542`
  `public struct _ResolvedKeyframes<Value> { }` пуст, и членов нет ни у него, ни у `_ResolvedKeyframe`
  (там только `Sendable`). Поэтому имена, которые несут нашу дорожку, — наши: `keyframes`,
  `initialValue`, `initialVelocity`, `progress(at:)`, `duration`, `value(at:)` у `_ResolvedKeyframes`
  и `_ResolvedKeyframe`, `to`/`duration`/`timing`/`startVelocity`/`endVelocity` у
  `_ResolvedKeyframeTrackContent`, и `Timing`. Они и должны быть видны: их читает проверка дорожки в
  тестах движка. Хранилища самих ключевых кадров (`CubicKeyframe.to`, `LinearKeyframe.to`,
  `SpringKeyframe.to`, `MoveKeyframe.to` и их `duration`/`spring`/`startVelocity`/`endVelocity`)
  внутренние — Apple объявляет у ключевого кадра только `init` и `_resolve`, и лишнего публичного
  имени на типе Apple быть не должно. `GlassEffect` — наш, внутренний: толщина стекла на iOS 6 это
  альфа заливки, а не свойство `Glass`. Сам `Glass` теперь как у Apple: `regular`, `clear`,
  `identity`, `Equatable`, без хранимых свойств и без `init`.

- `Double` и `Float` отвечают `Animatable` сами собой (`animatableData` — сам тип), как у Apple: без этого дорожку
  ключевых кадров нельзя построить над числом.

## Как собрать в рабочей копии ревью

Пакеты берутся из общего хранилища xmake, и `pkg-env.sh` спрашивает путь к каждому у самого xmake
(`xmake where` в `rtpkg`), поэтому рабочей копии ничего не нужно, кроме установки этих пакетов на машине:

```
(cd rtpkg && xmake f -p iphoneos -a armv7 -y)
```

`local.env` нужен только для `run-emu.sh` и `snapshots.sh`, а не для сборки. Проверки таблиц
(`eidolon/tools/tabletests/run.sh`) читают `eidolon/out/mods`, который пишет `eidolon/build.sh`.

## Ограничения окружения

- Приложение с интерфейсом запускается только установленным в `/Applications`; из временной папки
  iOS 6 не отдаёт ему дисплей (`GSRegisterPurpleNamedPort`, ошибка 1100). Поэтому на устройстве гоняется
  только безоконный пробник, а UI проверяется в эмуляторе.
- `UIFont` в процессе без `UIApplication` на iOS 6 падает, поэтому консольные тесты не используют текст.
- iLEmu на 6.1.3 не поднимает SpringBoard, UI-прогоны идут на iPod4,1 6.0.

## Наблюдения, которые ждут разбора

- **Кнопка остаётся полупрозрачной после касания.** `Button(action:) { Text("Tap me").frame(width: 280,
  height: 120).background(Color.white) }` в `VStack` приложения на пакете `charon@eidolon` (коммит 10f87e0),
  запущенного `xmake emulate launch` на iPhone4,1 6.1.3 (Shade), после `tap 160 271` вызвала действие один раз
  (`tapped 1`, текст и фон сменились), но и через секунду гостевого времени без изменений экрана кнопка
  нарисована как нажатая: белый фон и надпись полупрозрачны. Снимки до и после касания —
  `docs/device/button-before-tap-shade.png`, `docs/device/button-after-tap-shade.png`. На устройстве не
  проверялось; не разобрано, остаётся ли подсветка после отпускания или так рисуется выключенная кнопка.
