import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeSteps - Modo Hijo'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User Info
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                currentUser?.name.substring(0, 1).toUpperCase() ?? 'H',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hola, ${currentUser?.name ?? 'Hijo'}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu ubicación está siendo compartida',
              style: TextStyle(color: Colors.grey),
            ),
            
            const SizedBox(height: 48),
            
            // Panic Button
            SizedBox(
              width: 200,
              height: 200,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement panic alert
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Alerta de pánico enviada!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  elevation: 8,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'SOS',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Status Button
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement "I'm here" or status update
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ubicación actualizada'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Estoy bien'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
