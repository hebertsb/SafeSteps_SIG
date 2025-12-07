import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../sos/presentation/widgets/sos_button.dart';

class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationTrackingProvider.notifier).startTracking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final trackingState = ref.watch(locationTrackingProvider);
    final lastLocation = ref.watch(lastLocationProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Modo Hijo', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              ref.read(locationTrackingProvider.notifier).stopTracking();
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header Profile
            _buildProfileHeader(currentUser?.name ?? 'Hijo'),
            const SizedBox(height: 30),

            // Status Dashboard
            _buildStatusDashboard(trackingState, lastLocation),
            const SizedBox(height: 30),

            // SOS Button
            _buildSOSButton(
              currentUser != null ? int.tryParse(currentUser.id) : null,
              currentUser?.name,
            ),
            const SizedBox(height: 30),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hola, $name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Protección Activa',
                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDashboard(AsyncValue<void> trackingState, DateTime? lastUpdate) {
    final isTracking = !trackingState.isLoading && !trackingState.hasError;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusItem(
                icon: isTracking ? Icons.gps_fixed : Icons.gps_off,
                color: isTracking ? Colors.blue : Colors.grey,
                label: 'GPS',
                value: isTracking ? 'Activo' : 'Inactivo',
              ),
              _buildVerticalDivider(),
              _buildStatusItem(
                icon: Icons.access_time,
                color: Colors.orange,
                label: 'Última vez',
                value: lastUpdate != null 
                  ? DateFormat('HH:mm:ss').format(lastUpdate)
                  : '--:--',
              ),
              _buildVerticalDivider(),
              _buildStatusItem(
                icon: Icons.battery_std,
                color: Colors.green,
                label: 'Batería',
                value: '95%', // TODO: Get real battery level
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          // Zone Status Placeholder
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de Zona',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      'Monitoreado por el Tutor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSOSButton(int? id, String? name) {
    if (id == null) return const SizedBox.shrink();
    
    return SOSButton(
      hijoId: id,
      nombreHijo: name ?? 'Hijo',
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(locationTrackingProvider.notifier).startTracking();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ubicación actualizada manualmente'),
              backgroundColor: Colors.green,
            ),
          );
        },
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Estoy bien - Actualizar'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
