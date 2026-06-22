import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// [EmptyStateView] is a reusable widget designed to show empty lists
/// or states in the application. It displays a beautiful Lottie animation
/// with a title, description, and an optional call-to-action button.
class EmptyStateView extends StatelessWidget {
  final String lottieUrl;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData fallbackIcon;

  const EmptyStateView({
    super.key,
    required this.lottieUrl,
    required this.title,
    required this.description,
    this.buttonText,
    this.onButtonPressed,
    this.fallbackIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie Animation with network error handling fallback
            SizedBox(
              height: 160,
              width: 160,
              child: Lottie.network(
                lottieUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback icon if user is offline or URL fails to load
                  return Icon(
                    fallbackIcon,
                    size: 72,
                    color: Colors.grey.shade300,
                  );
                },
                frameBuilder: (context, child, composition) {
                  if (composition == null) {
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    );
                  }
                  return child;
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(buttonText!),
                onPressed: onButtonPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
