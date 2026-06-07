import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/vault_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoxVaultApp());
}

/// Root widget do aplicativo NoxVault.
class NoxVaultApp extends StatelessWidget {
  const NoxVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        // VaultProvider não carrega notas aqui — só após autenticação.
        ChangeNotifierProvider(create: (_) => VaultProvider()),
      ],
      child: Consumer2<AuthProvider, VaultProvider>(
        builder: (context, auth, vault, _) {
          // Quando o usuário autentica e a vaultKey está disponível,
          // as notas são carregadas automaticamente.
          if (auth.isAuthenticated && auth.vaultKey != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (vault.notes.isEmpty) {
                vault.loadNotes(auth.vaultKey!);
              }
            });
          }

          // Quando o usuário sai, limpa as notas da memória.
          if (!auth.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              vault.clearMemory();
            });
          }

          return MaterialApp(
            title: 'NoxVault',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.grey.shade800,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              useMaterial3: true,
            ),
            home: auth.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
