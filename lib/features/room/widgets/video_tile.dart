import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_initials.dart';

class VideoTile extends StatefulWidget {
  const VideoTile({
    super.key,
    required this.stream,
    required this.name,
    this.isSelf = false,
    this.speaking = false,
    this.camEnabled = true,
    this.isHost = false,
    this.isMuted = false,
    this.handRaised = false,
  });

  final MediaStream stream;
  final String name;
  final bool isSelf;
  final bool speaking;
  final bool camEnabled;
  final bool isHost;
  final bool isMuted;
  final bool handRaised;

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  final _renderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _renderer.initialize().then((_) {
      _renderer.srcObject = widget.stream;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(VideoTile old) {
    super.didUpdateWidget(old);
    if (old.stream != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VtColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.speaking ? VtColors.success : VtColors.border,
          width: widget.speaking ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        // Video or avatar placeholder
        if (widget.camEnabled)
          RTCVideoView(
            _renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: widget.isSelf,
          )
        else
          _AvatarPlaceholder(name: widget.name),

        // Name badge (bottom-left)
        Positioned(
          left: 8, bottom: 8, right: 8,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.isHost) ...[
                  const Icon(Icons.star_rounded, size: 11, color: VtColors.warning),
                  const SizedBox(width: 3),
                ],
                Flexible(child: Text(
                  widget.isSelf ? '${widget.name} (You)' : widget.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
            ),
            const Spacer(),
            if (widget.isMuted)
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_off_rounded, size: 12, color: Colors.white),
              ),
          ]),
        ),

        // Speaking indicator
        if (widget.speaking)
          Positioned(
            right: 8, top: 8,
            child: Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                color: VtColors.success, shape: BoxShape.circle),
            ),
          ),

        // Hand-raised indicator
        if (widget.handRaised)
          Positioned(
            left: 8, top: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.back_hand_rounded, size: 14, color: VtColors.warning),
            ),
          ),
      ]),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = avatarInitials(name);
    return Container(
      color: VtColors.surface2,
      child: Center(
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: VtColors.primaryBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(initials,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                  color: VtColors.primary)),
          ),
        ),
      ),
    );
  }
}
