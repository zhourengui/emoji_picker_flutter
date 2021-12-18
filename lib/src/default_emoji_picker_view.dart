import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/src/category_emoji.dart';
import 'package:emoji_picker_flutter/src/config.dart';
import 'package:emoji_picker_flutter/src/emoji_picker_builder.dart';
import 'package:emoji_picker_flutter/src/emoji_view_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Default EmojiPicker Implementation
class DefaultEmojiPickerView extends EmojiPickerBuilder {
  /// Constructor
  DefaultEmojiPickerView(Config config, EmojiViewState state)
      : super(config, state);

  @override
  _DefaultEmojiPickerViewState createState() => _DefaultEmojiPickerViewState();
}

class _DefaultEmojiPickerViewState extends State<DefaultEmojiPickerView>
    with SingleTickerProviderStateMixin {
  PageController? _pageController;
  TabController? _tabController;
  OverlayEntry? overlay;
  final ScrollController _scrollController = ScrollController();
  final skinToneCount = 6;

  @override
  void initState() {
    var initCategory = widget.state.categoryEmoji.indexWhere(
        (element) => element.category == widget.config.initCategory);
    if (initCategory == -1) {
      initCategory = 0;
    }
    _tabController = TabController(
        initialIndex: initCategory,
        length: widget.state.categoryEmoji.length,
        vsync: this);
    _pageController = PageController(initialPage: initCategory);

    _scrollController.addListener(closeSkinToneDialog);
    super.initState();
  }

  void closeSkinToneDialog() {
    overlay?.remove();
    overlay = null;
  }

  Widget _buildBackspaceButton() {
    if (widget.state.onBackspacePressed != null) {
      return Material(
        type: MaterialType.transparency,
        child: IconButton(
            padding: const EdgeInsets.only(bottom: 2),
            icon: Icon(
              Icons.backspace,
              color: widget.config.backspaceColor,
            ),
            onPressed: () {
              widget.state.onBackspacePressed!();
            }),
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final emojiSize = widget.config.getEmojiSize(constraints.maxWidth);

        return Container(
          color: widget.config.bgColor,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      labelColor: widget.config.iconColorSelected,
                      indicatorColor: widget.config.indicatorColor,
                      unselectedLabelColor: widget.config.iconColor,
                      controller: _tabController,
                      labelPadding: EdgeInsets.zero,
                      onTap: (index) {
                        _pageController!.jumpToPage(index);
                      },
                      tabs: widget.state.categoryEmoji
                          .asMap()
                          .entries
                          .map<Widget>((item) =>
                              _buildCategory(item.key, item.value.category))
                          .toList(),
                    ),
                  ),
                  _buildBackspaceButton(),
                ],
              ),
              Flexible(
                child: PageView.builder(
                  itemCount: widget.state.categoryEmoji.length,
                  controller: _pageController,
                  onPageChanged: (index) {
                    _tabController!.animateTo(
                      index,
                      duration: widget.config.tabIndicatorAnimDuration,
                    );
                  },
                  itemBuilder: (context, index) =>
                      _buildPage(emojiSize, widget.state.categoryEmoji[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategory(int index, Category category) {
    return Tab(
      icon: Icon(
        widget.config.getIconForCategory(category),
      ),
    );
  }

  Widget _buildPage(double emojiSize, CategoryEmoji categoryEmoji) {
    // Display notice if recent has no entries yet
    if (categoryEmoji.category == Category.RECENT &&
        categoryEmoji.emoji.isEmpty) {
      return _buildNoRecent();
    }
    // Build page normally
    return GridView.count(
      scrollDirection: Axis.vertical,
      physics: const ScrollPhysics(),
      controller: _scrollController,
      shrinkWrap: true,
      primary: false, // changed
      padding: const EdgeInsets.all(0),
      crossAxisCount: widget.config.columns,
      mainAxisSpacing: widget.config.verticalSpacing,
      crossAxisSpacing: widget.config.horizontalSpacing,
      children: categoryEmoji.emoji.asMap().entries.map((item) {
        final emoji = item.value;
        final onPressed = () {
          widget.state.onEmojiSelected(categoryEmoji.category, emoji);
        };

        final onLongPressed = () {
          if (!emoji.hasSkinTone) return;
          var row = item.key ~/ widget.config.columns;
          var column = item.key % widget.config.columns;
          overlay?.remove();
          overlay = _createSkinToneOverlay(
              emoji, emojiSize, categoryEmoji, row, column);
          Overlay.of(context)?.insert(overlay!);
        };

        return _buildEmoji(
          onPressed,
          onLongPressed,
          emojiSize,
          categoryEmoji,
          emoji,
        );
      }).toList(),
    );
  }

  Widget _buildEmoji(
    VoidCallback onPressed,
    VoidCallback onLongPressed,
    double emojiSize,
    CategoryEmoji categoryEmoji,
    Emoji emoji,
  ) {
    return _buildButtonWidget(
      onPressed: onPressed,
      onLongPressed: onLongPressed,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Text(
          emoji.emoji,
          textScaleFactor: 1.0,
          style: TextStyle(
            fontSize: emojiSize,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildButtonWidget({
    required VoidCallback onPressed,
    required VoidCallback onLongPressed,
    required Widget child,
  }) {
    if (widget.config.buttonMode == ButtonMode.MATERIAL) {
      return TextButton(
        onPressed: onPressed,
        onLongPress: onLongPressed,
        child: child,
        style: ButtonStyle(padding: MaterialStateProperty.all(EdgeInsets.zero)),
      );
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: child,
    );
  }

  Widget _buildNoRecent() {
    return Center(
        child: Text(
      widget.config.noRecentsText,
      style: widget.config.noRecentsStyle,
      textAlign: TextAlign.center,
    ));
  }

  /// Overlay for SkinTone
  OverlayEntry _createSkinToneOverlay(
    Emoji emoji,
    double emojiSize,
    CategoryEmoji categoryEmoji,
    int row,
    int column,
  ) {
    var renderBox = context.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    var emojiWidth = renderBox.size.width / widget.config.columns;
    var aboveOffset = emojiWidth;
    var leftOffset = getLeftOffset(emojiWidth, column);
    var left = offset.dx + column * emojiWidth + leftOffset;
    var top =
        offset.dy + row * emojiWidth - _scrollController.offset - aboveOffset;
    var width = skinToneCount * emojiWidth;
    var height = emojiWidth;

    var skinTone1 = emoji.copyWith(emoji: '${emoji.emoji}🏻');
    var skinTone2 = emoji.copyWith(emoji: '${emoji.emoji}🏼');
    var skinTone3 = emoji.copyWith(emoji: '${emoji.emoji}🏽');
    var skinTone4 = emoji.copyWith(emoji: '${emoji.emoji}🏾');
    var skinTone5 = emoji.copyWith(emoji: '${emoji.emoji}🏿');

    return OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 4.0,
          child: Container(
            width: width,
            height: height,
            color: widget.config.skinToneDialogBgColor,
            child: Row(
              children: [
                _buildEmoji(() {
                  widget.state.onEmojiSelected(categoryEmoji.category, emoji);
                  closeSkinToneDialog();
                }, () {}, emojiSize, categoryEmoji, emoji),
                _buildEmoji(() {
                  widget.state
                      .onEmojiSelected(categoryEmoji.category, skinTone1);
                  closeSkinToneDialog();
                }, () {}, emojiSize, categoryEmoji, skinTone1),
                _buildEmoji(() {
                  widget.state
                      .onEmojiSelected(categoryEmoji.category, skinTone2);
                  closeSkinToneDialog();
                }, () {}, emojiSize, categoryEmoji, skinTone2),
                _buildEmoji(() {
                  widget.state
                      .onEmojiSelected(categoryEmoji.category, skinTone3);
                  closeSkinToneDialog();
                }, () {}, emojiSize, categoryEmoji, skinTone3),
                _buildEmoji(() {
                  widget.state
                      .onEmojiSelected(categoryEmoji.category, skinTone4);
                  closeSkinToneDialog();
                }, () {}, emojiSize, categoryEmoji, skinTone4),
                _buildEmoji(() {
                  widget.state
                      .onEmojiSelected(categoryEmoji.category, skinTone5);
                  closeSkinToneDialog();
                }, () {}, emojiSize, categoryEmoji, skinTone5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double getLeftOffset(double emojiWidth, int column) {
    var remainingColumns =
        widget.config.columns - (column + 1 + (skinToneCount ~/ 2));
    if (column >= 0 && column < 3) {
      return -1 * column * emojiWidth;
    } else if (remainingColumns < 0) {
      return -1 *
          ((skinToneCount ~/ 2 - 1) + -1 * remainingColumns) *
          emojiWidth;
    }
    return -1 * ((skinToneCount ~/ 2) * emojiWidth) + emojiWidth / 2;
  }
}
