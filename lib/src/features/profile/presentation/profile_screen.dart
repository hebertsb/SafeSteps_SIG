import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../map/presentation/providers/children_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SafeSteps', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Ubicación en tiempo real', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Container(
        color: AppColors.background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tarjeta del Padre/Madre
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.name ?? 'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser?.email ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Sección de Hijos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hijos Registrados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            childrenAsync.when(
              data: (children) => Column(
                children: children.map((child) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          child.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          child.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: child.status == 'online' ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: child.status == 'online' ? Colors.green.shade700 : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                child.status == 'online' ? 'En línea' : 'Desconectado',
                                style: TextStyle(
                                  color: child.status == 'online' ? Colors.green.shade700 : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          '${child.age} años • ${child.device}',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_android, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '+34 612 345 678',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                )).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),

            const SizedBox(height: 24),
            
            // Sección de Configuración
            const Text(
              'Configuración',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            _buildConfigItem(
              icon: Icons.notifications,
              iconColor: Colors.orange,
              title: 'Notificaciones',
              subtitle: 'Configurar alertas',
            ),
            
            _buildConfigItem(
              icon: Icons.shield,
              iconColor: Colors.orange.shade700,
              title: 'Privacidad',
              subtitle: 'Seguridad y permisos',
            ),
            
            _buildConfigItem(
              icon: Icons.history,
              iconColor: Colors.orange.shade600,
              title: 'Historial',
              subtitle: 'Ver ubicaciones pasadas',
            ),
            
            const SizedBox(height: 24),
            
            OutlinedButton.icon(
              onPressed: () async {
                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
