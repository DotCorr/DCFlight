"""Design-companion registration and platform-first authoring guidance.

Static, read-only authoring knowledge compiled into the tool. No network
access, no execution. The Appllama block is a registration for agents
(where to connect the design-library MCP and skills); it is documentation,
not code, and is never required to compile or ship an app.
"""

APPLLLAMA = {
    'id': 'appllama',
    'name': 'Appllama design library',
    'summary': 'Design library of top-grossing mobile apps: real screens, flows and UI '
               'patterns with revenue and download context. The skill pair turns that '
               'library into a working method: appllama-usage decides what to study, '
               'appllama-app-design-skill decides how to build.',
    'endpoint': 'https://mcp.appllama.io/mcp',
    'connect': 'Register the endpoint as a remote MCP connector in Claude, Cursor, '
               'Codex or any MCP client, then approve with an Appllama account. '
               'MCP access is part of Appllama Pro; every call spends one credit '
               '(get_credits is always free).',
    'install': 'npx skills@latest add appllama/appllama-skills',
    'skills': ['appllama-usage', 'appllama-app-design-skill'],
    'repo': 'https://github.com/Appllama/appllama-skills',
    'license': 'MIT (skills). The Appllama name, llama and logo are trademarks of '
               'Antmind Ventures Private Limited; the license does not grant rights to use them.',
    'notes': [
        'Default design companion for DCFlight authoring agents. Platform-first '
        'components come first; Appllama refines the result against top-grossing apps.',
        'Optional and user-owned: agents or users with their own design skills may '
        'replace or supplement it. Nothing here is required to compile or ship.',
        'Not bundled with dcflight and never auto-installed; this registration is '
        'documentation for agents, not executed code.',
    ],
}

TOPICS = {
    'overview': {
        'summary': 'Author platform-first. The compiler lowers composite components to '
                   'SwiftUI idioms on iOS (NavigationStack, List, TabView) and Material 3 '
                   'on Android (Scaffold, LazyColumn, NavigationBar). Reach for primitives '
                   'only when the design intentionally diverges from the platform.',
        'rules': [
            'Prefer the composite component tier (list, listItem, section, navigation, form) over hand-assembled primitives; primitives are the custom-UI escape hatch.',
            'Match each platform\'s native look: inset grouped lists on iOS, Material cards and elevation on Android. Do not clone one platform\'s chrome onto the other.',
            'Study top-grossing reference designs before building new screens; the Appllama MCP (see companion) exists for exactly this.',
            'Finish in a simulator or on device: scroll every screen, respect safe areas, and verify both platforms before calling a screen done.',
        ],
    },
    'list': {
        'summary': 'Use list/listItem/section composites; the compiler emits SwiftUI List '
                   'on iOS and LazyColumn with Material list items on Android.',
        'rules': [
            'Inset grouped style for settings-like screens on iOS; Material cards in LazyColumn on Android.',
            'Minimum row height 44pt (iOS) / 48dp (Android); keep tap targets generous.',
            'Leading accessory ~29pt for row iconography on iOS; trailing chevron only when the row pushes a detail screen.',
            'Sticky section headers on both platforms; destructive rows are red and require confirmation.',
        ],
    },
    'navigation': {
        'summary': 'Push for detail, sheet for focused tasks, tab for top-level destinations. '
                   'iOS lowers to NavigationStack, Android to Scaffold + predictive back.',
        'rules': [
            'Sheets for self-contained tasks that can be cancelled; push for hierarchical detail.',
            'One-way doors: after irreversible completion (paywall, signup, destructive confirm) back must not return to the gate.',
            'Keep navigation state in the app definition; the compiler owns the native stack per platform.',
        ],
    },
    'form': {
        'summary': 'Forms lower to grouped inset lists on iOS and Material text fields on '
                   'Android, with correct keyboards and submit labels.',
        'rules': [
            'Declare keyboard type and submit label per field; numeric for quantities, email/url where applicable.',
            'Validate inline next to the field, not in a detached alert.',
            'Respect keyboard avoidance (iOS) and IME insets (Android); the primary action stays reachable.',
        ],
    },
    'cards': {
        'summary': 'Cards are composite components, not padded boxes. iOS insetGrouped for '
                   'grouped content; Android Material cards with elevation tokens.',
        'rules': [
            'Use the theme radius/padding tokens instead of bespoke per-screen values.',
            'One primary action per card; secondary actions go into an overflow or detail push.',
            'Do not stack shadows on iOS grouped lists; elevation is an Android Material affordance.',
        ],
    },
    'tabbar': {
        'summary': 'Top-level destinations only. iOS lowers to TabView, Android to '
                   'NavigationBar (Material 3).',
        'rules': [
            '3-5 top-level destinations; never a tab that only wraps settings you could push.',
            'No tab bars inside pushed detail; the platform stack owns that decision.',
            'Badges carry counts or unread state, never decoration.',
        ],
    },
}

_ALIASES = {
    'lists': 'list', 'listitem': 'list', 'rows': 'list', 'section': 'list',
    'nav': 'navigation', 'routing': 'navigation', 'stack': 'navigation',
    'forms': 'form', 'inputs': 'form', 'textfields': 'form',
    'tab': 'tabbar', 'tabs': 'tabbar', 'tabbar': 'tabbar',
    '': 'overview',
}


def guidance(topic=None):
    """Return authoring guidance for a topic, with the companion registration attached."""
    key = str(topic or '').strip().lower()
    key = _ALIASES.get(key, key)
    if key not in TOPICS:
        return {'error': 'Unknown topic: {}'.format(topic),
                'available': sorted(TOPICS), 'companion': APPLLLAMA}
    data = dict(TOPICS[key])
    data['companion'] = APPLLLAMA
    return data
