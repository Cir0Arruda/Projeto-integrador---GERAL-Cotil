import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/api_client.dart';

Future<String?> requestWithdrawalApproval(
  BuildContext context,
  String code,
  double quantity,
) async {
  final password = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WithdrawalPasswordDialog(code: code, quantity: quantity),
  );
  if (password == null) return null;
  if (!kIsWeb) {
    try {
      final auth = LocalAuthentication();
      if (!(await auth.canCheckBiometrics) ||
          (await auth.getAvailableBiometrics()).isEmpty) {
        throw const ApiException(
          'Cadastre uma biometria no dispositivo para aprovar retiradas.',
        );
      }
      if (!await auth.authenticate(
        localizedReason: 'Aprovar retirada de $quantity de $code',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      )) {
        return null;
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível validar sua biometria. A retirada não foi enviada.',
      );
    }
  }
  return password;
}

class _WithdrawalPasswordDialog extends StatefulWidget {
  const _WithdrawalPasswordDialog({required this.code, required this.quantity});
  final String code;
  final double quantity;
  @override
  State<_WithdrawalPasswordDialog> createState() =>
      _WithdrawalPasswordDialogState();
}

class _WithdrawalPasswordDialogState extends State<_WithdrawalPasswordDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Aprovar retirada'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Material: ${widget.code}\nQuantidade: ${widget.quantity}'),
          const SizedBox(height: 12),
          Text(
            kIsWeb
                ? 'No navegador, a confirmação é pela senha ASTHA. A biometria está disponível no aplicativo instalado em dispositivo compatível.'
                : 'Confirme sua senha ASTHA. Em seguida, o dispositivo solicitará sua biometria.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Senha atual da conta ASTHA',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.isNotEmpty) {
            Navigator.pop(context, controller.text);
          }
        },
        child: const Text('Confirmar retirada'),
      ),
    ],
  );
}
