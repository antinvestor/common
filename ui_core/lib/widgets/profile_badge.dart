import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Creates a [ProfileAvatar] from any object that has a profileId and name.
///
/// Works with AgentObject, ClientObject, InvestorObject, SystemUserObject,
/// or any object with `profileId` and `name` String fields.
///
/// Usage:
/// ```dart
/// ProfileAvatar.from(agent)            // avatar only
/// ProfileBadge.from(agent)             // avatar + name
/// ProfileBadge.from(agent, description: 'Field Agent')
/// ```
///

/// A palette of pleasant, deterministic colors for profile avatars.
const _avatarColors = [
  Color(0xFF2E7D5F), // teal
  Color(0xFF5C6BC0), // indigo
  Color(0xFFAB47BC), // purple
  Color(0xFF26A69A), // cyan-teal
  Color(0xFFEF6C00), // deep orange
  Color(0xFF1565C0), // blue
  Color(0xFF00897B), // dark teal
  Color(0xFF6D4C41), // brown
  Color(0xFF7B1FA2), // deep purple
  Color(0xFFC62828), // red
];

/// Returns a deterministic color from [_avatarColors] based on [name].
Color _colorForName(String name) {
  var hash = 0;
  for (var i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return _avatarColors[hash.abs() % _avatarColors.length];
}

/// Returns initials from [name]: first letter of first + last word,
/// or first two characters if a single word.
String _initialsFrom(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return trimmed.length >= 2
      ? trimmed.substring(0, 2).toUpperCase()
      : trimmed[0].toUpperCase();
}

// ---------------------------------------------------------------------------
// ProfileAvatar -- compact circle with initials, tap/hover shows popup
// ---------------------------------------------------------------------------

/// A compact circular avatar that shows initials from the user's name.
///
/// On tap (mobile) or hover (web), a [ProfilePopupCard] is displayed.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.profileId,
    required this.name,
    this.description,
    this.size = 36,
    this.onPrimaryColor = Colors.white,
  });

  /// Create from any proto object with `profileId` and `name` fields.
  ///
  /// Usage: `ProfileAvatar.of(profileId: agent.profileId, name: agent.name)`
  /// or use the named constructor for common objects.
  factory ProfileAvatar.of({
    Key? key,
    required String profileId,
    required String name,
    String? description,
    double size = 36,
  }) => ProfileAvatar(
    key: key,
    profileId: profileId,
    name: name,
    description: description,
    size: size,
  );

  final String profileId;
  final String name;
  final String? description;
  final double size;

  /// Text / icon color rendered on top of the avatar background.
  final Color onPrimaryColor;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

  void _showPopup() {
    _removePopup();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _PopupOverlay(
        layerLink: _layerLink,
        profileId: widget.profileId,
        name: widget.name,
        description: widget.description,
        onDismiss: _removePopup,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removePopup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _colorForName(widget.name);
    final initials = _initialsFrom(widget.name);
    final fontSize = widget.size * 0.38;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isHovering = true;
          _showPopup();
        },
        onExit: (_) {
          _isHovering = false;
          // Short delay so the user can move into the popup.
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_isHovering) _removePopup();
          });
        },
        child: GestureDetector(
          onTap: _showPopup,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: widget.onPrimaryColor,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The overlay wrapper for the popup card, positioned relative to the avatar.
class _PopupOverlay extends StatelessWidget {
  const _PopupOverlay({
    required this.layerLink,
    required this.profileId,
    required this.name,
    this.description,
    required this.onDismiss,
  });

  final LayerLink layerLink;
  final String profileId;
  final String name;
  final String? description;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss area
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          offset: const Offset(0, 44),
          child: Material(
            color: Colors.transparent,
            child: ProfilePopupCard(
              profileId: profileId,
              name: name,
              description: description,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ProfileBadge -- medium: avatar + name + description in a row
// ---------------------------------------------------------------------------

/// A medium-sized profile widget showing avatar, name, optional description,
/// and a copy-ID icon. The profile ID is never displayed as text.
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({
    super.key,
    required this.profileId,
    required this.name,
    this.description,
    this.avatarSize = 40,
    this.trailing,
    this.nameColor,
    this.descriptionColor,
  });

  /// Create from any object with profileId and name fields.
  ///
  /// ```dart
  /// ProfileBadge.of(
  ///   profileId: agent.profileId,
  ///   name: agent.name,
  ///   description: 'Field Agent',
  /// )
  /// ```
  factory ProfileBadge.of({
    Key? key,
    required String profileId,
    required String name,
    String? description,
    double avatarSize = 40,
    Widget? trailing,
  }) => ProfileBadge(
    key: key,
    profileId: profileId,
    name: name,
    description: description,
    avatarSize: avatarSize,
    trailing: trailing,
  );

  final String profileId;
  final String name;
  final String? description;
  final double avatarSize;

  /// Optional widget shown after the name column (e.g. an action button).
  final Widget? trailing;

  /// Override for the name text color (useful on dark backgrounds).
  final Color? nameColor;

  /// Override for the description text color.
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatar(
          profileId: profileId,
          name: name,
          description: description,
          size: avatarSize,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: nameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (description != null && description!.isNotEmpty)
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        descriptionColor ?? theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ] else ...[
          const SizedBox(width: 4),
          _CopyIdButton(profileId: profileId),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ProfilePopupCard -- detailed card shown on hover / tap
// ---------------------------------------------------------------------------

/// A detailed profile card with avatar, name, description, and a "Copy ID"
/// action row. Intended to be shown in an overlay or dialog.
class ProfilePopupCard extends StatelessWidget {
  const ProfilePopupCard({
    super.key,
    required this.profileId,
    required this.name,
    this.description,
    this.extraRows,
  });

  final String profileId;
  final String name;
  final String? description;

  /// Additional info rows (e.g. role, branch) rendered below the ID row.
  final List<Widget>? extraRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(profileId: profileId, name: name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description != null && description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Copy ID row
              _CopyIdRow(profileId: profileId),
              if (extraRows != null)
                for (final row in extraRows!) ...[
                  const SizedBox(height: 4),
                  row,
                ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

/// Small icon button that copies [profileId] to clipboard and shows feedback.
class _CopyIdButton extends StatelessWidget {
  const _CopyIdButton({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy profile ID',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _copyId(context, profileId),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.copy_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A row showing "Copy ID" label and copy icon, used inside [ProfilePopupCard].
class _CopyIdRow extends StatelessWidget {
  const _CopyIdRow({required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _copyId(context, profileId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Copy ID',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies [profileId] to the system clipboard and shows a brief snackbar.
void _copyId(BuildContext context, String profileId) {
  Clipboard.setData(ClipboardData(text: profileId));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Copied profile ID'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      width: 200,
    ),
  );
}
