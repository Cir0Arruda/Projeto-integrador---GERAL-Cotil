import 'package:flutter/material.dart';
import '../core/config.dart';

/// Select an explicit API origin before starting an unconfigured release.
class ApiSetup extends StatefulWidget {
  const ApiSetup({super.key, required this.onConfigured});
  final Future<void> Function(String url) onConfigured;
  @override
  State<ApiSetup> createState() => _ApiSetupState();
}

class _ApiSetupState extends State<ApiSetup> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = AppConfig.normalizeServerUrl(_controller.text);
      await widget.onConfigured(url);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Informe a origem HTTPS do seu servidor ASTHA. Confira o endereço com o administrador.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xff158453),
    ),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/logo.png', height: 64),
                const SizedBox(height: 24),
                const Text(
                  'Conectar ao ASTHA',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Informe o endereço do servidor da sua conta para continuar.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Endereço do servidor',
                    hintText: 'https://...',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Conectando…' : 'Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
