import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int _pinLength = 4;

Future<String?> showSetPinDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _SetPinDialog(),
  );
}

Future<String?> showAskPinDialog(
  BuildContext context, {
  String title = 'Ingresá tu PIN',
  String message = 'Necesitamos tu PIN actual para continuar',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskPinDialog(title: title, message: message),
  );
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  bool _confirming = false;
  String? _firstPin;
  String? _error;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (pin.length != _pinLength) {
      setState(() => _error = 'El PIN debe tener $_pinLength dígitos');
      return;
    }
    if (!_confirming) {
      _firstPin = pin;
      _confirming = true;
      _error = null;
      _controller.clear();
      setState(() {});
      return;
    }
    if (pin != _firstPin) {
      setState(() {
        _error = 'Los PIN no coinciden. Volvé a intentar';
        _confirming = false;
        _controller.clear();
      });
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_confirming ? 'Confirmá tu PIN' : 'Creá tu PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _confirming
                ? 'Repetí el mismo PIN para confirmarlo'
                : 'Elegí un PIN de $_pinLength dígitos para bloquear la aplicación',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: _pinLength,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              counterText: '',
              labelText: 'PIN',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_confirming ? 'Confirmar' : 'Continuar'),
        ),
      ],
    );
  }
}

class _AskPinDialog extends StatefulWidget {
  final String title;
  final String message;

  const _AskPinDialog({required this.title, required this.message});

  @override
  State<_AskPinDialog> createState() => _AskPinDialogState();
}

class _AskPinDialogState extends State<_AskPinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (pin.length != _pinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El PIN debe tener 4 dígitos')),
      );
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: _pinLength,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'PIN',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continuar')),
      ],
    );
  }
}
