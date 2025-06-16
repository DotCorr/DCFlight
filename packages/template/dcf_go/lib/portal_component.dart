import 'package:dcflight/dcflight.dart';

class DCFPortalHostWrapper extends StatelessComponent {
  final String targetId;
  final List<DCFComponentNode> children;

  DCFPortalHostWrapper({
    super.key,
    required this.targetId,
    required this.children,
  });

  @override
  DCFComponentNode render() {
    return DCFFragment(
      children: [
        DCFPortal(
          targetId: targetId,
          createTarget: true,
          children: children,
        ),
      ],
    );
  }
}

class DCFPortalReceiverWrapper extends StatelessComponent {
  final String targetId;

  DCFPortalReceiverWrapper({super.key, required this.targetId});

  @override
  DCFComponentNode render() {
    return DCFFragment(
      children: [
        DCFPortalContainer(targetId: targetId, layout: LayoutProps(flex: 1)),
      ],
    );
  }
}
