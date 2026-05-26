import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/review_service.dart';

class CustomRatingDialog extends StatefulWidget {
  final Function(double, String) onGoodReview;
  final Function(double, String) onBadReview;

  const CustomRatingDialog({
    Key? key,
    required this.onGoodReview,
    required this.onBadReview,
  }) : super(key: key);

  @override
  _CustomRatingDialogState createState() => _CustomRatingDialogState();

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CustomRatingDialog(
        onGoodReview: (rating, comment) async {
          Navigator.pop(context);
          await ReviewService().neverAskAgain();
          ReviewService().forceRequestReview();
        },
        onBadReview: (rating, comment) async {
          if (context.mounted) Navigator.pop(context);
          await ReviewService().markFeedbackGiven();
          ReviewService().sendEmailFeedback(rating, comment);
        },
      ),
    );
  }
}

class _CustomRatingDialogState extends State<CustomRatingDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: SingleChildScrollView(
        /// Added to handle keyboard/long content
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "How’s your experience?",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(

                  "Your feedback helps us improve\nand serve you better.",

                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              /// Star Rating
              RatingBar.builder(
                initialRating: 5,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                unratedColor: Colors.grey[200],
                itemSize: 45,
                itemBuilder: (context, _) =>
                const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                onRatingUpdate: (rating) {
                  setState(() => _rating = rating);
                },
              ),

              /// Conditional Feedback Logic
              AnimatedSize(
                /// Smoothly expands when textfield appears
                duration: const Duration(milliseconds: 300),
                child: Visibility(
                  visible: _rating < 4,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      style: GoogleFonts.manrope(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                          'Any comments or feedback? (Optional)',
                        hintStyle: GoogleFonts.manrope(color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              /// Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_rating >= 4) {
                      widget.onGoodReview(_rating, _commentController.text);
                    } else {
                      widget.onBadReview(_rating, _commentController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Submit',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              /// Skip Button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Skip for Now',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
