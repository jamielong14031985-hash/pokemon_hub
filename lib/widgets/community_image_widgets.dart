import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'stored_image.dart';

class CommunityImageStrip extends StatelessWidget {
  const CommunityImageStrip({
    super.key,
    required this.imageBase64List,
    required this.height,
  });

  final List<String> imageBase64List;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageBase64List.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageBase64List.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CommunityImageViewerPage(
                    imageBase64List: imageBase64List,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFF16366E)),
                    StoredImage(
                      imageRef: imageBase64List[index],
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${index + 1}/${imageBase64List.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CommunityImageViewerPage extends StatefulWidget {
  const CommunityImageViewerPage({
    super.key,
    required this.imageBase64List,
    required this.initialIndex,
  });

  final List<String> imageBase64List;
  final int initialIndex;

  @override
  State<CommunityImageViewerPage> createState() =>
      __CommunityImageViewerPageState();
}

class __CommunityImageViewerPageState extends State<CommunityImageViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      math.max(0, widget.imageBase64List.length - 1),
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.imageBase64List.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageBase64List.length,
        onPageChanged: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: StoredImage(
                imageRef: widget.imageBase64List[index],
                fit: BoxFit.contain,
                errorChild: const Text(
                  'Image could not be loaded',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
