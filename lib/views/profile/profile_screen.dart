import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/cart_service.dart';
import '../../config/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService().currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.secondaryNeon.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 40,
                      color: AppTheme.secondaryNeon,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.companyName ?? 'Acme Corp',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.role ?? 'Authorized Partner',
                    style: const TextStyle(
                      color: AppTheme.primaryNeon,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            Text(
              'Company Details',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Profile info cards
            _buildProfileInfoItem(context, label: 'Primary Contact', value: user?.contactName ?? 'John Doe'),
            _buildProfileInfoItem(context, label: 'Billing Email Address', value: user?.email ?? 'partner@acme.com'),
            _buildProfileInfoItem(context, label: 'Account ID Ref', value: user?.uid ?? 'N/A'),
            _buildProfileInfoItem(context, label: 'Try-On Status', value: 'Unlimited AI Checks'),

            const SizedBox(height: 32),

            // Quick links
            Text(
              'My Activity',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Cart tile
            ValueListenableBuilder<int>(
              valueListenable: CartService().cartCountNotifier,
              builder: (context, count, _) {
                return _buildActivityTile(
                  context,
                  icon: Icons.shopping_bag_rounded,
                  label: 'My Cart',
                  badge: count > 0 ? '$count item${count > 1 ? 's' : ''}' : null,
                  color: const Color(0xFF0066CC),
                  onTap: () => Navigator.pushNamed(context, '/cart'),
                );
              },
            ),
            const SizedBox(height: 10),

            // Wishlist tile
            _buildActivityTile(
              context,
              icon: Icons.bookmark_rounded,
              label: 'Saved Items',
              badge: null,
              color: AppTheme.primaryNeon,
              onTap: () => Navigator.pushNamed(context, '/wishlist'),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile edit is locked for verification purposes.'),
                      backgroundColor: AppTheme.darkCard,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.glassBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Request Account Update',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoItem(BuildContext context, {required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? badge,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

