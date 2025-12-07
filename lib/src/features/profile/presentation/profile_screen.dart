import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/socket_provider.dart';
import '../../map/domain/entities/child.dart';
import '../../map/presentation/providers/children_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, Child> _liveChildren = {};
  StreamSubscription? _locationSub;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocketListeners();
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    final socketService = ref.read(socketServiceProvider);
    
    // Listen for location updates
    _locationSub = socketService.locationStream.listen((data) {
      if (mounted) {
        final childId = data['childId'].toString();
        final newDevice = data['device'] as String? ?? 'Unknown';
        setState(() {
          if (_liveChildren.containsKey(childId)) {
            final currentDevice = _liveChildren[childId]!.device;
            _liveChildren[childId] = _liveChildren[childId]!.copyWith(
              battery: (data['battery'] as num).toDouble(),
              status: 'online',
              device: newDevice != 'Unknown' ? newDevice : currentDevice,
              lastUpdated: DateTime.now(),
            );
          }
        });
      }
    });

    // Listen for status changes
    _statusSub = socketService.statusStream.listen((data) {
      if (mounted) {
        final childId = data['childId'].toString();
        final isOnline = data['online'] as bool;
        final newDevice = data['device'] as String? ?? 'Unknown';
        setState(() {
          if (_liveChildren.containsKey(childId)) {
            final currentDevice = _liveChildren[childId]!.device;
            _liveChildren[childId] = _liveChildren[childId]!.copyWith(
              status: isOnline ? 'online' : 'offline',
              device: newDevice != 'Unknown' ? newDevice : currentDevice,
              lastUpdated: DateTime.now(),
            );
          }
        });
      }
    });
  }

  Child _getLiveChild(Child child) {
    return _liveChildren[child.id] ?? child;
  }

  void _initializeLiveChildren(List<Child> children) {
    for (final child in children) {
      if (!_liveChildren.containsKey(child.id)) {
        _liveChildren[child.id] = child;
        // Join socket room for this child
        final socketService = ref.read(socketServiceProvider);
        if (socketService.isConnected) {
          socketService.joinChildRoom(child.id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);
    final currentUser = ref.watch(currentUserProvider);

    // Initialize live children when data is available
    childrenAsync.whenData((children) {
      _initializeLiveChildren(children);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SafeSteps',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Ubicación en tiempo real', style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta del Tutor
                  _buildTutorCard(currentUser?.name, currentUser?.email),
                  
                  const SizedBox(height: 24),

                  // Sección de Hijos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hijos Registrados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      _AddChildButton(
                        onPressed: () => context.push('/create-child'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Lista de Hijos con scroll
                  childrenAsync.when(
                    data: (children) => children.isEmpty
                        ? _buildEmptyChildrenState()
                        : _buildChildrenList(context, children.map((c) => _getLiveChild(c)).toList()),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Error: $err'),
                      ),
                    ),
                  ),
                  
                  // Espacio extra para el botón flotante
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      // Botón de Logout fijo en la parte inferior (arriba del navbar)
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 130), // 130px para estar arriba del navbar
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
        ),
        child: _AnimatedLogoutButton(
          onLogout: () async {
            await ref.read(authControllerProvider.notifier).logout();
          },
        ),
      ),
    );
  }

  Widget _buildTutorCard(String? name, String? email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tutor',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChildrenState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.child_care_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay hijos registrados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega un hijo para comenzar a monitorear',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenList(BuildContext context, List children) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.builder(
        shrinkWrap: true,
        physics: children.length > 3 
            ? const AlwaysScrollableScrollPhysics() 
            : const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          return _ChildCard(
            child: child,
            onTap: () => context.push('/child-detail', extra: child),
          );
        },
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddChildButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Agregar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final dynamic child;
  final VoidCallback onTap;

  const _ChildCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline = child.status == 'online';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar con emoji
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      child.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? Colors.green.shade600
                                        : Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'En línea' : 'Offline',
                                  style: TextStyle(
                                    color: isOnline
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        child.device,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLogoutButton extends StatefulWidget {
  final VoidCallback onLogout;

  const _AnimatedLogoutButton({required this.onLogout});

  @override
  State<_AnimatedLogoutButton> createState() => _AnimatedLogoutButtonState();
}

class _AnimatedLogoutButtonState extends State<_AnimatedLogoutButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _personAnimation;
  late Animation<double> _doorAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _personAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _doorAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onLogout();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!_isAnimating) {
      HapticFeedback.mediumImpact();
      setState(() => _isAnimating = true);
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isAnimating
                    ? [Colors.red.shade600, Colors.red.shade800]
                    : [Colors.red.shade500, Colors.red.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(_isAnimating ? 0.4 : 0.25),
                  blurRadius: _isAnimating ? 15 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Person walking out with text (centered)
                  Transform.translate(
                    offset: Offset(_personAnimation.value * 50, 0),
                    child: Opacity(
                      opacity: 1 - (_personAnimation.value * 0.3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isAnimating
                                ? Icons.directions_walk_rounded
                                : Icons.logout_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAnimating ? 'Saliendo...' : 'Cerrar Sesión',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Door frame - positioned to the right, opens when person exits
                  Positioned(
                    right: 24,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateY(_doorAnimation.value * -1.2), // rotate on Y axis (open door effect)
                      alignment: Alignment.centerLeft, // hinge on left side
                      child: Icon(
                        Icons.door_back_door_outlined,
                        color: Colors.white.withOpacity(0.9 - _doorAnimation.value * 0.3),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

