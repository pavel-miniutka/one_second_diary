import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../routes/app_pages.dart';
import '../../../utils/constants.dart';
import '../../../utils/ffmpeg_api_wrapper.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/utils.dart';

class VideoSubtitlesEditorPage extends StatefulWidget {
  const VideoSubtitlesEditorPage({
    super.key,
    required this.videoPath,
    required this.subtitles,
  });

  final String videoPath;
  final String subtitles;

  @override
  State<VideoSubtitlesEditorPage> createState() =>
      _VideoSubtitlesEditorPageState();
}

class _VideoSubtitlesEditorPageState extends State<VideoSubtitlesEditorPage> {
  final logTag = '[SUBTITLES EDITOR PAGE] - ';
  double _opacity = 1.0;
  String _subtitles = '';
  bool isProcessing = false;
  bool isEdit = false;
  late VideoPlayerController _videoController;
  final TextEditingController subtitlesController = TextEditingController();

  @override
  void initState() {
    _initVideoPlayerController();
    if (widget.subtitles.isNotEmpty) {
      _subtitles = widget.subtitles
          .trim()
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      subtitlesController.text = _subtitles;
      isEdit = true;
    }

    super.initState();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _initVideoPlayerController() {
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _videoController.setLooping(true);
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('subtitles'.tr),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        child: !isProcessing
            ? const Icon(
                Icons.save,
                color: Colors.white,
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
        onPressed: () async {
          setState(() {
            isProcessing = true;
          });
          final subtitles = await Utils.writeSrt(
            _subtitles,
            _videoController.value.duration.inMilliseconds.toDouble(),
          );

          String command = '';
          final String tempPath =
              '${widget.videoPath.split('.mp4').first}_temp.mp4';

          if (isEdit) {
            Utils.logWarning(
                '${logTag}Editing subtitles for ${widget.videoPath}');
          } else {
            Utils.logWarning(
                '${logTag}Adding brand new subtitles for ${widget.videoPath}');
          }

          // TODO(me): this will have to be saved to docsDir instead of direct path and then copied to MediaStore folder
          command =
              '-i ${widget.videoPath} -i $subtitles -c:s mov_text -c:v copy -c:a copy -map 0:v -map 0:a? -map 1 -disposition:s:0 default $tempPath -y';

          await executeFFmpeg(command).then((session) async {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              Utils.logInfo('${logTag}Video subtitles updated successfully!');
              StorageUtils.deleteFile(widget.videoPath);
              StorageUtils.renameFile(tempPath, widget.videoPath);

              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'subtitlesSaved'.tr,
                  ),
                ),
              );
            } else {
              Utils.logError('${logTag}Video subtitles update failed!');
              final sessionLog = await session.getLogsAsString();
              final failureStackTrace = await session.getFailStackTrace();
              Utils.logError('${logTag}Session log: $sessionLog');
              Utils.logError('${logTag}Failure stacktrace: $failureStackTrace');
            }
          });

          setState(() {
            isProcessing = false;
          });

          Get.offAllNamed(Routes.HOME)?.then((_) => setState(() {}));
        },
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: () => videoPlay(),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      VideoPlayer(
                        key: UniqueKey(),
                        _videoController,
                      ),
                      Center(
                        child: Opacity(
                          opacity: _opacity,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.25,
                            height: MediaQuery.of(context).size.width * 0.25,
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow,
                                size: 72.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: subtitlesController,
                  maxLines: null,
                  onChanged: (value) => setState(() {
                    _subtitles = value;
                  }),
                  decoration: InputDecoration(
                    hintText: ('enterSubtitles'.tr).split('(').first,
                    filled: true,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.green),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.green),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void videoPlay() async {
    if (!_videoController.value.isPlaying) {
      await _videoController.play();
      setState(() {
        _opacity = 0.0;
      });
    } else {
      await _videoController.pause();
      setState(() {
        _opacity = 1.0;
      });
    }
  }
}
