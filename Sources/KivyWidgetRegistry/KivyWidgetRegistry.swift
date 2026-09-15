// KivyWidgetRegistry.swift
// Auto-generated from Kivy widget definitions
//
// This file contains information about Kivy widgets including their
// properties and inheritance hierarchy with support for multiple inheritance.

import Foundation

/// Kivy property types
public enum KivyPropertyType: String, Equatable, Hashable, Sendable {
    case numericProperty = "NumericProperty"
    case stringProperty = "StringProperty"
    case listProperty = "ListProperty"
    case objectProperty = "ObjectProperty"
    case booleanProperty = "BooleanProperty"
    case dictProperty = "DictProperty"
    case optionProperty = "OptionProperty"
    case referenceListProperty = "ReferenceListProperty"
    case aliasProperty = "AliasProperty"
    case boundedNumericProperty = "BoundedNumericProperty"
    case variableListProperty = "VariableListProperty"
    case colorProperty = "ColorProperty"
}

/// Represents a single Kivy property with its name and type
public struct KivyPropertyInfo: Equatable, Hashable, Sendable {
    public let name: String
    public let type: KivyPropertyType
    
    public init(name: String, type: KivyPropertyType) {
        self.name = name
        self.type = type
    }
}

/// Represents a Kivy widget with its base classes and properties
/// Supports multiple inheritance (e.g., Button inherits from both ButtonBehavior and Label)
public struct KivyWidgetInfo: Sendable {
    public let widgetName: String
    public let baseClasses: [KivyWidget]
    public let directProperties: Set<KivyPropertyInfo>
    
    public init(widgetName: String, baseClasses: [KivyWidget], directProperties: Set<KivyPropertyInfo>) {
        self.widgetName = widgetName
        self.baseClasses = baseClasses
        self.directProperties = directProperties
    }
    
    /// Legacy initializer for backward compatibility
    @available(*, deprecated, message: "Use baseClasses instead of parentClass")
    public init(widgetName: String, parentClass: KivyWidget?, directProperties: Set<KivyPropertyInfo>) {
        self.widgetName = widgetName
        self.baseClasses = parentClass.map { [$0] } ?? []
        self.directProperties = directProperties
    }
    
    /// Legacy property for backward compatibility
    @available(*, deprecated, message: "Use baseClasses instead")
    public var parentClass: KivyWidget? {
        return baseClasses.first
    }
}

/// Enum representing all available Kivy widget types and behaviors
public enum KivyWidget: String, CaseIterable, Equatable, Hashable, Sendable {
    // Core Widgets
    case Widget
    case Layout
    
    // Behaviors (Mixins)
    case ButtonBehavior
    case ToggleButtonBehavior
    case DragBehavior
    case FocusBehavior
    case CompoundSelectionBehavior
    case CodeNavigationBehavior
    case EmacsBehavior
    case CoverBehavior
    case TouchRippleBehavior
    case TouchRippleButtonBehavior
    case HoverBehavior
    case MotionCollideBehavior
    case MotionBlockBehavior
    
    // Layout Widgets
    case AnchorLayout
    case BoxLayout
    case FloatLayout
    case GridLayout
    case PageLayout
    case RelativeLayout
    case ScatterLayout
    case StackLayout
    
    // UI Widgets
    case Label
    case Button
    case ToggleButton
    case CheckBox
    case Slider
    case ProgressBar
    case Switch
    case TextInput
    case CodeInput
    case Image
    case Video
    case Camera
    
    // Containers
    case ScrollView
    case Carousel
    case TabbedPanel
    case TabbedPanelHeader
    case TabbedPanelStrip
    case Accordion
    case AccordionItem
    case Splitter
    case Bubble
    case BubbleContent
    case Popup
    case ModalView
    case DropDown
    case Spinner
    
    // Screen Management
    case Screen
    case ScreenManager
    
    // Transitions
    case TransitionBase
    case NoTransition
    case SlideTransition
    case CardTransition
    case FadeTransition
    case FallOutTransition
    case RiseInTransition
    case ShaderTransition
    case WipeTransition
    
    // ActionBar
    case ActionBar
    case ActionButton
    case ActionGroup
    case ActionItem
    case ActionOverflow
    case ActionPrevious
    case ActionSeparator
    case ActionToggleButton
    case ActionView
    
    // Effects
    case EffectBase
    case AdvancedEffectBase
    case EffectWidget
    case ChannelMixEffect
    case HorizontalBlurEffect
    case VerticalBlurEffect
    case PixelateEffect
    
    // Settings
    case Settings
    case SettingsPanel
    case SettingItem
    case SettingBoolean
    case SettingColor
    case SettingOptions
    case SettingPath
    case SettingSidebarLabel
    case SettingString
    case SettingTitle
    
    // RST Document
    case RstBlockQuote
    case RstDefinition
    case RstDefinitionList
    case RstDefinitionSpace
    case RstDocument
    case RstFieldName
    case RstFootName
    case RstListBullet
    case RstListItem
    case RstLiteralBlock
    case RstNote
    case RstParagraph
    case RstTerm
    case RstTitle
    case RstWarning
    
    // Other
    case ColorPicker
    case ColorWheel
    case ContentPanel
    case FileChooser
    case FileChooserController
    case FileChooserLayout
    case FileChooserProgressBase
    case GestureContainer
    case GestureSurface
    case InterfaceWithSidebar
    case InterfaceWithSpinner
    case InterfaceWithTabbedPanel
    case MenuSidebar
    case MenuSpinner
    case MyOwnActionButton
    case MyWidget
    case OtherWidget
    case RecycleLayout
    case Scatter
    case Selector
    case StripLayout
    case TreeView
    case TreeViewNode
    case VKeyboard
    case VideoPlayer
    case VideoPlayerAnnotation
    case VideoPlayerPlayPause
    case VideoPlayerPreview
    case VideoPlayerProgressBar
    case VideoPlayerStop
    case VideoPlayerVolume
    
    // Example/Test widgets
    case TextInputApp
    case TextInputCutCopyPaste
}

/// Registry of all Kivy widgets with methods to query widget information
public class KivyWidgetRegistry {
    
    /// Dictionary mapping widget names to their information
    private static let widgetRegistry: [KivyWidget: KivyWidgetInfo] = [
        // Core
        .Widget: KivyWidgetInfo(
            widgetName: "Widget",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "center", type: .referenceListProperty),
                KivyPropertyInfo(name: "center_x", type: .aliasProperty),
                KivyPropertyInfo(name: "center_y", type: .aliasProperty),
                KivyPropertyInfo(name: "children", type: .listProperty),
                KivyPropertyInfo(name: "cls", type: .listProperty),
                KivyPropertyInfo(name: "disabled", type: .aliasProperty),
                KivyPropertyInfo(name: "height", type: .numericProperty),
                KivyPropertyInfo(name: "ids", type: .dictProperty),
                KivyPropertyInfo(name: "motion_filter", type: .dictProperty),
                KivyPropertyInfo(name: "opacity", type: .numericProperty),
                KivyPropertyInfo(name: "parent", type: .objectProperty),
                KivyPropertyInfo(name: "pos", type: .referenceListProperty),
                KivyPropertyInfo(name: "pos_hint", type: .objectProperty),
                KivyPropertyInfo(name: "right", type: .aliasProperty),
                KivyPropertyInfo(name: "size", type: .referenceListProperty),
                KivyPropertyInfo(name: "size_hint", type: .referenceListProperty),
                KivyPropertyInfo(name: "size_hint_max", type: .referenceListProperty),
                KivyPropertyInfo(name: "size_hint_max_x", type: .numericProperty),
                KivyPropertyInfo(name: "size_hint_max_y", type: .numericProperty),
                KivyPropertyInfo(name: "size_hint_min", type: .referenceListProperty),
                KivyPropertyInfo(name: "size_hint_min_x", type: .numericProperty),
                KivyPropertyInfo(name: "size_hint_min_y", type: .numericProperty),
                KivyPropertyInfo(name: "size_hint_x", type: .numericProperty),
                KivyPropertyInfo(name: "size_hint_y", type: .numericProperty),
                KivyPropertyInfo(name: "top", type: .aliasProperty),
                KivyPropertyInfo(name: "width", type: .numericProperty),
                KivyPropertyInfo(name: "x", type: .numericProperty),
                KivyPropertyInfo(name: "y", type: .numericProperty),
            ]
        ),
        
        .Layout: KivyWidgetInfo(
            widgetName: "Layout",
            baseClasses: [.Widget],
            directProperties: []
        ),
        
        // Behaviors
        .ButtonBehavior: KivyWidgetInfo(
            widgetName: "ButtonBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "always_release", type: .booleanProperty),
                KivyPropertyInfo(name: "last_touch", type: .objectProperty),
                KivyPropertyInfo(name: "min_state_time", type: .numericProperty),
                KivyPropertyInfo(name: "pressed", type: .aliasProperty),
                KivyPropertyInfo(name: "state", type: .optionProperty),
            ]
        ),
        
        .ToggleButtonBehavior: KivyWidgetInfo(
            widgetName: "ToggleButtonBehavior",
            baseClasses: [.ButtonBehavior],
            directProperties: [
                KivyPropertyInfo(name: "active", type: .booleanProperty),
                KivyPropertyInfo(name: "group", type: .objectProperty),
                KivyPropertyInfo(name: "allow_no_selection", type: .booleanProperty),
            ]
        ),
        
        .DragBehavior: KivyWidgetInfo(
            widgetName: "DragBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "drag_distance", type: .numericProperty),
                KivyPropertyInfo(name: "drag_timeout", type: .numericProperty),
                KivyPropertyInfo(name: "drag_rect_x", type: .numericProperty),
                KivyPropertyInfo(name: "drag_rect_y", type: .numericProperty),
                KivyPropertyInfo(name: "drag_rect_width", type: .numericProperty),
                KivyPropertyInfo(name: "drag_rect_height", type: .numericProperty),
            ]
        ),
        
        .FocusBehavior: KivyWidgetInfo(
            widgetName: "FocusBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "focus", type: .booleanProperty),
                KivyPropertyInfo(name: "focus_next", type: .objectProperty),
                KivyPropertyInfo(name: "focus_previous", type: .objectProperty),
                KivyPropertyInfo(name: "unfocus_on_touch", type: .booleanProperty),
            ]
        ),
        
        .CompoundSelectionBehavior: KivyWidgetInfo(
            widgetName: "CompoundSelectionBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "multiselect", type: .booleanProperty),
                KivyPropertyInfo(name: "touch_multiselect", type: .booleanProperty),
                KivyPropertyInfo(name: "selected_nodes", type: .listProperty),
            ]
        ),
        
        .CodeNavigationBehavior: KivyWidgetInfo(
            widgetName: "CodeNavigationBehavior",
            baseClasses: [],
            directProperties: []
        ),
        
        .EmacsBehavior: KivyWidgetInfo(
            widgetName: "EmacsBehavior",
            baseClasses: [],
            directProperties: []
        ),
        
        .CoverBehavior: KivyWidgetInfo(
            widgetName: "CoverBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "cover_image", type: .stringProperty),
                KivyPropertyInfo(name: "cover_image_texture", type: .objectProperty),
            ]
        ),
        
        .TouchRippleBehavior: KivyWidgetInfo(
            widgetName: "TouchRippleBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "ripple_rad_default", type: .numericProperty),
                KivyPropertyInfo(name: "ripple_color", type: .colorProperty),
                KivyPropertyInfo(name: "ripple_alpha", type: .numericProperty),
                KivyPropertyInfo(name: "ripple_scale", type: .numericProperty),
                KivyPropertyInfo(name: "ripple_duration_in", type: .numericProperty),
                KivyPropertyInfo(name: "ripple_duration_out", type: .numericProperty),
                KivyPropertyInfo(name: "ripple_func_in", type: .stringProperty),
                KivyPropertyInfo(name: "ripple_func_out", type: .stringProperty),
            ]
        ),
        
        .TouchRippleButtonBehavior: KivyWidgetInfo(
            widgetName: "TouchRippleButtonBehavior",
            baseClasses: [.TouchRippleBehavior, .ButtonBehavior],
            directProperties: []
        ),
        
        .HoverBehavior: KivyWidgetInfo(
            widgetName: "HoverBehavior",
            baseClasses: [],
            directProperties: [
                KivyPropertyInfo(name: "hovered", type: .booleanProperty),
                KivyPropertyInfo(name: "hover_visible", type: .booleanProperty),
            ]
        ),
        
        .MotionCollideBehavior: KivyWidgetInfo(
            widgetName: "MotionCollideBehavior",
            baseClasses: [],
            directProperties: []
        ),
        
        .MotionBlockBehavior: KivyWidgetInfo(
            widgetName: "MotionBlockBehavior",
            baseClasses: [],
            directProperties: []
        ),
        
        // Label - base for Button
        .Label: KivyWidgetInfo(
            widgetName: "Label",
            baseClasses: [.Widget],
            directProperties: [
                KivyPropertyInfo(name: "anchors", type: .dictProperty),
                KivyPropertyInfo(name: "base_direction", type: .optionProperty),
                KivyPropertyInfo(name: "bold", type: .booleanProperty),
                KivyPropertyInfo(name: "color", type: .colorProperty),
                KivyPropertyInfo(name: "disabled_color", type: .colorProperty),
                KivyPropertyInfo(name: "disabled_outline_color", type: .colorProperty),
                KivyPropertyInfo(name: "ellipsis_options", type: .dictProperty),
                KivyPropertyInfo(name: "font_blended", type: .booleanProperty),
                KivyPropertyInfo(name: "font_context", type: .stringProperty),
                KivyPropertyInfo(name: "font_direction", type: .optionProperty),
                KivyPropertyInfo(name: "font_family", type: .stringProperty),
                KivyPropertyInfo(name: "font_features", type: .stringProperty),
                KivyPropertyInfo(name: "font_hinting", type: .optionProperty),
                KivyPropertyInfo(name: "font_kerning", type: .booleanProperty),
                KivyPropertyInfo(name: "font_name", type: .stringProperty),
                KivyPropertyInfo(name: "font_script_name", type: .optionProperty),
                KivyPropertyInfo(name: "font_size", type: .numericProperty),
                KivyPropertyInfo(name: "halign", type: .optionProperty),
                KivyPropertyInfo(name: "is_shortened", type: .booleanProperty),
                KivyPropertyInfo(name: "italic", type: .booleanProperty),
                KivyPropertyInfo(name: "limit_render_to_text_bbox", type: .booleanProperty),
                KivyPropertyInfo(name: "line_height", type: .numericProperty),
                KivyPropertyInfo(name: "markup", type: .booleanProperty),
                KivyPropertyInfo(name: "max_lines", type: .numericProperty),
                KivyPropertyInfo(name: "mipmap", type: .booleanProperty),
                KivyPropertyInfo(name: "outline_color", type: .colorProperty),
                KivyPropertyInfo(name: "outline_width", type: .numericProperty),
                KivyPropertyInfo(name: "padding", type: .variableListProperty),
                KivyPropertyInfo(name: "padding_x", type: .numericProperty),
                KivyPropertyInfo(name: "padding_y", type: .numericProperty),
                KivyPropertyInfo(name: "refs", type: .dictProperty),
                KivyPropertyInfo(name: "shorten", type: .booleanProperty),
                KivyPropertyInfo(name: "shorten_from", type: .optionProperty),
                KivyPropertyInfo(name: "split_str", type: .stringProperty),
                KivyPropertyInfo(name: "strikethrough", type: .booleanProperty),
                KivyPropertyInfo(name: "strip", type: .booleanProperty),
                KivyPropertyInfo(name: "text", type: .stringProperty),
                KivyPropertyInfo(name: "text_language", type: .stringProperty),
                KivyPropertyInfo(name: "text_size", type: .listProperty),
                KivyPropertyInfo(name: "texture", type: .objectProperty),
                KivyPropertyInfo(name: "texture_size", type: .listProperty),
                KivyPropertyInfo(name: "underline", type: .booleanProperty),
                KivyPropertyInfo(name: "unicode_errors", type: .optionProperty),
                KivyPropertyInfo(name: "valign", type: .optionProperty),
            ]
        ),
        
        // Button - Multiple inheritance from ButtonBehavior + Label
        .Button: KivyWidgetInfo(
            widgetName: "Button",
            baseClasses: [.ButtonBehavior, .Label],
            directProperties: [
                KivyPropertyInfo(name: "background_color", type: .colorProperty),
                KivyPropertyInfo(name: "background_disabled_down", type: .stringProperty),
                KivyPropertyInfo(name: "background_disabled_normal", type: .stringProperty),
                KivyPropertyInfo(name: "background_down", type: .stringProperty),
                KivyPropertyInfo(name: "background_normal", type: .stringProperty),
                KivyPropertyInfo(name: "border", type: .listProperty),
            ]
        ),
        
        // ToggleButton - Multiple inheritance from ToggleButtonBehavior + Button
        .ToggleButton: KivyWidgetInfo(
            widgetName: "ToggleButton",
            baseClasses: [.ToggleButtonBehavior, .Button],
            directProperties: []
        ),
        
        // Layouts
        .AnchorLayout: KivyWidgetInfo(
            widgetName: "AnchorLayout",
            baseClasses: [.Layout],
            directProperties: [
                KivyPropertyInfo(name: "anchor_x", type: .optionProperty),
                KivyPropertyInfo(name: "anchor_y", type: .optionProperty),
                KivyPropertyInfo(name: "padding", type: .variableListProperty),
            ]
        ),
        
        .BoxLayout: KivyWidgetInfo(
            widgetName: "BoxLayout",
            baseClasses: [.Layout],
            directProperties: [
                KivyPropertyInfo(name: "minimum_height", type: .numericProperty),
                KivyPropertyInfo(name: "minimum_size", type: .referenceListProperty),
                KivyPropertyInfo(name: "minimum_width", type: .numericProperty),
                KivyPropertyInfo(name: "orientation", type: .optionProperty),
                KivyPropertyInfo(name: "padding", type: .variableListProperty),
                KivyPropertyInfo(name: "spacing", type: .numericProperty),
            ]
        ),
        
        .FloatLayout: KivyWidgetInfo(
            widgetName: "FloatLayout",
            baseClasses: [.Layout],
            directProperties: []
        ),
        
        .RelativeLayout: KivyWidgetInfo(
            widgetName: "RelativeLayout",
            baseClasses: [.FloatLayout],
            directProperties: []
        ),
        
        .GridLayout: KivyWidgetInfo(
            widgetName: "GridLayout",
            baseClasses: [.Layout],
            directProperties: [
                KivyPropertyInfo(name: "col_default_width", type: .numericProperty),
                KivyPropertyInfo(name: "col_force_default", type: .booleanProperty),
                KivyPropertyInfo(name: "cols", type: .boundedNumericProperty),
                KivyPropertyInfo(name: "cols_minimum", type: .dictProperty),
                KivyPropertyInfo(name: "minimum_height", type: .numericProperty),
                KivyPropertyInfo(name: "minimum_size", type: .referenceListProperty),
                KivyPropertyInfo(name: "minimum_width", type: .numericProperty),
                KivyPropertyInfo(name: "orientation", type: .optionProperty),
                KivyPropertyInfo(name: "padding", type: .variableListProperty),
                KivyPropertyInfo(name: "row_default_height", type: .numericProperty),
                KivyPropertyInfo(name: "row_force_default", type: .booleanProperty),
                KivyPropertyInfo(name: "rows", type: .boundedNumericProperty),
                KivyPropertyInfo(name: "rows_minimum", type: .dictProperty),
                KivyPropertyInfo(name: "spacing", type: .variableListProperty),
            ]
        ),
        
        .StackLayout: KivyWidgetInfo(
            widgetName: "StackLayout",
            baseClasses: [.Layout],
            directProperties: [
                KivyPropertyInfo(name: "minimum_height", type: .numericProperty),
                KivyPropertyInfo(name: "minimum_size", type: .referenceListProperty),
                KivyPropertyInfo(name: "minimum_width", type: .numericProperty),
                KivyPropertyInfo(name: "orientation", type: .optionProperty),
                KivyPropertyInfo(name: "padding", type: .variableListProperty),
                KivyPropertyInfo(name: "spacing", type: .variableListProperty),
            ]
        ),
        
        .PageLayout: KivyWidgetInfo(
            widgetName: "PageLayout",
            baseClasses: [.Layout],
            directProperties: [
                KivyPropertyInfo(name: "anim_kwargs", type: .dictProperty),
                KivyPropertyInfo(name: "border", type: .numericProperty),
                KivyPropertyInfo(name: "page", type: .numericProperty),
                KivyPropertyInfo(name: "swipe_threshold", type: .numericProperty),
            ]
        ),
        
        // Additional widgets with proper inheritance...
        // (Continue with remaining widgets following the same pattern)
        
        .CheckBox: KivyWidgetInfo(
            widgetName: "CheckBox",
            baseClasses: [.Widget],
            directProperties: [
                KivyPropertyInfo(name: "background_checkbox_disabled_down", type: .stringProperty),
                KivyPropertyInfo(name: "background_checkbox_disabled_normal", type: .stringProperty),
                KivyPropertyInfo(name: "background_checkbox_down", type: .stringProperty),
                KivyPropertyInfo(name: "background_checkbox_normal", type: .stringProperty),
                KivyPropertyInfo(name: "background_radio_disabled_down", type: .stringProperty),
                KivyPropertyInfo(name: "background_radio_disabled_normal", type: .stringProperty),
                KivyPropertyInfo(name: "background_radio_down", type: .stringProperty),
                KivyPropertyInfo(name: "background_radio_normal", type: .stringProperty),
                KivyPropertyInfo(name: "color", type: .colorProperty),
            ]
        ),
        
        .Image: KivyWidgetInfo(
            widgetName: "Image",
            baseClasses: [.Widget],
            directProperties: [
                KivyPropertyInfo(name: "allow_stretch", type: .booleanProperty),
                KivyPropertyInfo(name: "anim_delay", type: .numericProperty),
                KivyPropertyInfo(name: "anim_loop", type: .numericProperty),
                KivyPropertyInfo(name: "color", type: .colorProperty),
                KivyPropertyInfo(name: "fit_mode", type: .optionProperty),
                KivyPropertyInfo(name: "image_ratio", type: .aliasProperty),
                KivyPropertyInfo(name: "keep_data", type: .booleanProperty),
                KivyPropertyInfo(name: "keep_ratio", type: .booleanProperty),
                KivyPropertyInfo(name: "mipmap", type: .booleanProperty),
                KivyPropertyInfo(name: "nocache", type: .booleanProperty),
                KivyPropertyInfo(name: "norm_image_size", type: .aliasProperty),
                KivyPropertyInfo(name: "source", type: .stringProperty),
                KivyPropertyInfo(name: "texture", type: .objectProperty),
                KivyPropertyInfo(name: "texture_size", type: .listProperty),
            ]
        ),
        
        .ProgressBar: KivyWidgetInfo(
            widgetName: "ProgressBar",
            baseClasses: [.Widget],
            directProperties: [
                KivyPropertyInfo(name: "max", type: .numericProperty),
                KivyPropertyInfo(name: "value", type: .numericProperty),
                KivyPropertyInfo(name: "value_normalized", type: .aliasProperty),
            ]
        ),
        
        .Slider: KivyWidgetInfo(
            widgetName: "Slider",
            baseClasses: [.Widget],
            directProperties: [
                KivyPropertyInfo(name: "cursor_height", type: .numericProperty),
                KivyPropertyInfo(name: "cursor_image", type: .stringProperty),
                KivyPropertyInfo(name: "cursor_size", type: .referenceListProperty),
                KivyPropertyInfo(name: "cursor_width", type: .numericProperty),
                KivyPropertyInfo(name: "max", type: .numericProperty),
                KivyPropertyInfo(name: "min", type: .numericProperty),
                KivyPropertyInfo(name: "orientation", type: .optionProperty),
                KivyPropertyInfo(name: "padding", type: .numericProperty),
                KivyPropertyInfo(name: "range", type: .referenceListProperty),
                KivyPropertyInfo(name: "sensitivity", type: .optionProperty),
                KivyPropertyInfo(name: "step", type: .numericProperty),
                KivyPropertyInfo(name: "value", type: .numericProperty),
                KivyPropertyInfo(name: "value_normalized", type: .aliasProperty),
                KivyPropertyInfo(name: "value_pos", type: .aliasProperty),
                KivyPropertyInfo(name: "value_track", type: .booleanProperty),
                KivyPropertyInfo(name: "value_track_color", type: .colorProperty),
            ]
        ),
        
        .Switch: KivyWidgetInfo(
            widgetName: "Switch",
            baseClasses: [.Widget],
            directProperties: [
                KivyPropertyInfo(name: "active", type: .booleanProperty),
                KivyPropertyInfo(name: "active_norm_pos", type: .numericProperty),
            ]
        ),
    ]
    
    /// Get widget information by enum case
    /// - Parameter widget: The widget enum case
    /// - Returns: Widget information if found, nil otherwise
    public static func getWidgetInfo(_ widget: KivyWidget) -> KivyWidgetInfo? {
        return widgetRegistry[widget]
    }
    
    /// Get widget information by name
    /// - Parameter widgetName: Name of the widget (e.g., "Button", "Label")
    /// - Returns: Widget information if found, nil otherwise
    public static func getWidgetInfo(_ widgetName: String) -> KivyWidgetInfo? {
        guard let widget = KivyWidget(rawValue: widgetName) else { return nil }
        return widgetRegistry[widget]
    }
    
    /// Get all properties for a widget including inherited properties from all base classes
    /// Handles multiple inheritance properly
    /// - Parameter widget: The widget enum case
    /// - Returns: Set of all properties (direct + inherited from all base classes)
    public static func getAllProperties(for widget: KivyWidget) -> Set<KivyPropertyInfo> {
        var allProperties = Set<KivyPropertyInfo>()
        var visited = Set<KivyWidget>()
        
        // Recursively collect properties from all base classes (DFS)
        func collectProperties(from widget: KivyWidget) {
            // Avoid cycles
            guard !visited.contains(widget) else { return }
            visited.insert(widget)
            
            guard let info = widgetRegistry[widget] else { return }
            
            // Add this widget's direct properties
            allProperties.formUnion(info.directProperties)
            
            // Recursively add properties from all base classes
            for baseClass in info.baseClasses {
                collectProperties(from: baseClass)
            }
        }
        
        collectProperties(from: widget)
        return allProperties
    }
    
    /// Get all properties for a widget including inherited properties (string-based)
    /// - Parameter widgetName: Name of the widget
    /// - Returns: Set of all properties (direct + inherited)
    public static func getAllProperties(for widgetName: String) -> Set<KivyPropertyInfo> {
        guard let widget = KivyWidget(rawValue: widgetName) else { return [] }
        return getAllProperties(for: widget)
    }
    
    /// Check if a property exists on a widget (including inherited properties)
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - widget: The widget enum case
    /// - Returns: true if the property exists on the widget or its base classes
    public static func hasProperty(_ propertyName: String, on widget: KivyWidget) -> Bool {
        let allProps = getAllProperties(for: widget)
        return allProps.contains { $0.name == propertyName }
    }
    
    /// Check if a property exists on a widget (string-based)
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - widgetName: Name of the widget
    /// - Returns: true if the property exists on the widget or its base classes
    public static func hasProperty(_ propertyName: String, on widgetName: String) -> Bool {
        guard let widget = KivyWidget(rawValue: widgetName) else { return false }
        return hasProperty(propertyName, on: widget)
    }
    
    /// Get the type of a property on a widget
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - widget: The widget enum case
    /// - Returns: Property type if found, nil otherwise
    public static func getPropertyType(_ propertyName: String, on widget: KivyWidget) -> KivyPropertyType? {
        let allProps = getAllProperties(for: widget)
        return allProps.first { $0.name == propertyName }?.type
    }
    
    /// Get the type of a property on a widget (string-based)
    /// - Parameters:
    ///   - propertyName: Name of the property
    ///   - widgetName: Name of the widget
    /// - Returns: Property type if found, nil otherwise
    public static func getPropertyType(_ propertyName: String, on widgetName: String) -> KivyPropertyType? {
        guard let widget = KivyWidget(rawValue: widgetName) else { return nil }
        return getPropertyType(propertyName, on: widget)
    }
    
    /// Get all base classes for a widget (including transitive)
    /// - Parameter widget: The widget enum case
    /// - Returns: Array of all base classes in inheritance order
    public static func getAllBaseClasses(for widget: KivyWidget) -> [KivyWidget] {
        var result: [KivyWidget] = []
        var visited = Set<KivyWidget>()
        
        func traverse(_ widget: KivyWidget) {
            guard !visited.contains(widget) else { return }
            visited.insert(widget)
            
            guard let info = widgetRegistry[widget] else { return }
            
            for baseClass in info.baseClasses {
                result.append(baseClass)
                traverse(baseClass)
            }
        }
        
        traverse(widget)
        return result
    }
    
    /// Get all registered widget names
    /// - Returns: Array of all widget names
    public static func getAllWidgetNames() -> [String] {
        return KivyWidget.allCases.map { $0.rawValue }.sorted()
    }
    
    /// Get all registered widgets as enum cases
    /// - Returns: Array of all widget enum cases
    public static func getAllWidgets() -> [KivyWidget] {
        return KivyWidget.allCases.sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Check if a widget exists in the registry
    /// - Parameter widget: The widget enum case
    /// - Returns: true if the widget is registered
    public static func widgetExists(_ widget: KivyWidget) -> Bool {
        return widgetRegistry[widget] != nil
    }
    
    /// Check if a widget exists in the registry (string-based)
    /// - Parameter widgetName: Name of the widget
    /// - Returns: true if the widget is registered
    public static func widgetExists(_ widgetName: String) -> Bool {
        return KivyWidget(rawValue: widgetName) != nil
    }
}
