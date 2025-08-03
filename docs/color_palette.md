# Medici App Color Palette Documentation

This document outlines the healthcare-focused color palette used throughout the Medici application. The colors have been carefully selected to convey trust, professionalism, and a sense of calm that is appropriate for a healthcare application.

## Primary Colors

| Color Name | Hex Code | RGB | Description | Usage |
|------------|----------|-----|-------------|-------|
| Primary Blue | #2c7bb6 | rgb(44, 123, 182) | Trustworthy blue | Primary buttons, links, headers, accents |
| Secondary Green | #16a085 | rgb(22, 160, 133) | Healing green | Secondary buttons, success states, accents |
| Success Green | #27ae60 | rgb(39, 174, 96) | Positive green | Success messages, positive indicators |
| Info Blue | #3498db | rgb(52, 152, 219) | Information blue | Information messages, secondary accents |
| Warning Amber | #f39c12 | rgb(243, 156, 18) | Cautionary amber | Warnings, attention-required elements |
| Danger Red | #e74c3c | rgb(231, 76, 60) | Alert red | Error messages, destructive actions |
| Light Gray | #f8f9fa | rgb(248, 249, 250) | Clean white | Backgrounds, cards |
| Dark Navy | #2c3e50 | rgb(44, 62, 80) | Deep navy | Text, footers |

## Neutral Colors

A range of gray tones for various UI elements:

| Color Name | Hex Code | RGB | Usage |
|------------|----------|-----|-------|
| Gray 100 | #f8f9fa | rgb(248, 249, 250) | Backgrounds, light borders |
| Gray 200 | #e9ecef | rgb(233, 236, 239) | Borders, dividers |
| Gray 300 | #dee2e6 | rgb(222, 226, 230) | Borders, dividers |
| Gray 400 | #ced4da | rgb(206, 212, 218) | Disabled states |
| Gray 500 | #adb5bd | rgb(173, 181, 189) | Placeholder text |
| Gray 600 | #6c757d | rgb(108, 117, 125) | Secondary text |
| Gray 700 | #495057 | rgb(73, 80, 87) | Body text |
| Gray 800 | #343a40 | rgb(52, 58, 64) | Headings |
| Gray 900 | #212529 | rgb(33, 37, 41) | Dark text |

## Additional Healthcare-Specific Colors

| Color Name | Hex Code | RGB | Description | Usage |
|------------|----------|-----|-------------|-------|
| Teal | #20c997 | rgb(32, 201, 151) | Medical scrubs teal | Accents, highlights |
| Cyan | #17a2b8 | rgb(23, 162, 184) | Clean blue | Secondary information |
| Indigo | #6610f2 | rgb(102, 16, 242) | Deep accent | Special highlights |

## Accessibility Considerations

All color combinations in the application have been checked for accessibility, ensuring:

- Text colors have sufficient contrast against their backgrounds (WCAG AA compliance)
- Interactive elements are clearly distinguishable
- Status information is not conveyed by color alone
- Focus states are clearly visible

## Implementation

The color palette is implemented by overriding Bootstrap variables in the `custom.scss` file. This ensures consistent application of colors throughout the UI while maintaining the familiar Bootstrap component structure.

## Usage Guidelines

1. **Primary Blue (#2c7bb6)** should be used for primary actions, main navigation, and key interactive elements.
2. **Secondary Green (#16a085)** should be used for secondary actions and success states.
3. **Light backgrounds** should be used for most content areas to maintain a clean, clinical feel.
4. **Warning and Danger colors** should be used sparingly and only for their intended purposes.
5. **Text colors** should maintain high contrast with backgrounds for readability.

## Examples

- Primary buttons: Primary Blue (#2c7bb6)
- Secondary buttons: Secondary Green (#16a085)
- Success messages: Success Green (#27ae60)
- Warning messages: Warning Amber (#f39c12)
- Error messages: Danger Red (#e74c3c)
- Main navigation: Primary Blue (#2c7bb6)
- Card headers: Primary Blue (#2c7bb6)
- Table headers: Primary Blue (#2c7bb6)
- Links: Primary Blue (#2c7bb6)
- Body text: Dark Gray (#343a40)