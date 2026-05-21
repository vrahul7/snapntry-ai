import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
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
            _buildProfileInfoItem(context, label: 'Current Credit Limit', value: '${user?.credits ?? 0} Credits'),

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
}
