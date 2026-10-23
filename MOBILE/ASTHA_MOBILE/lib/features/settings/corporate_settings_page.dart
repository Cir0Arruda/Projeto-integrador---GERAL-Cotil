// ============================================================================
// ★ CONFIGURAÇÕES CORPORATIVAS E DA EMPRESA (CORPORATE_SETTINGS_PAGE.DART) ★
// Gerencie os dados cadastrais da sua organização:
// 1) Razão social, nome fantasia e CNPJ da empresa :3
// 2) Endereço da sede e centros de distribuição (✿◠‿◠)
// 3) Políticas corporativas e personalização da marca! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/account_models.dart';
import '../../repositories/account_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/async_view.dart';

// Telinha de ajustes corporativos da organização :3
class CorporateSettingsPage extends StatefulWidget {
  const CorporateSettingsPage({super.key});

  @override
  State<CorporateSettingsPage> createState() => _CorporateSettingsPageState();
}

class _CorporateSettingsPageState extends State<CorporateSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cnpjController;
  late final TextEditingController _addressController;

  bool _saving = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _cnpjController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _populateForm(Organization org) {
    if (_nameController.text.isEmpty && org.name.isNotEmpty) {
      _nameController.text = org.name;
    }
    if (_cnpjController.text.isEmpty && org.cnpj != null) {
      _cnpjController.text = org.cnpj!;
    }
    if (_addressController.text.isEmpty && org.address != null) {
      _addressController.text = org.address!;
    }
  }

  Future<void> _saveOrganization() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.read<AccountRepository>();
    final session = context.read<SessionController>();
    try {
      await repo.updateOrganization(
        name: _nameController.text.trim(),
        cnpj: _cnpjController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (!mounted) return;
      await session.refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados da organização atualizados com sucesso.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao salvar: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openNewUnitDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text(
            'Nova Unidade / Filial',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código da unidade *',
                      hintText: 'Ex.: FIL-SP-01',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o código.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da unidade *',
                      hintText: 'Ex.: Filial Campinas',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o nome.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Finalidade operacional',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                try {
                  await context.read<AccountRepository>().createUnit(
                    code: codeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                  );
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(
                        content: Text('Erro: $e'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );

    codeCtrl.dispose();
    nameCtrl.dispose();
    descCtrl.dispose();

    if (created == true && mounted) {
      setState(() => _revision++);
    }
  }

  Future<void> _deleteUnit(OrgUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir unidade'),
        content: Text('Deseja realmente excluir a unidade "${unit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<AccountRepository>().deleteUnit(unit.id);
        if (mounted) setState(() => _revision++);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao excluir: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AccountRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Corporativo & Workspace')),
      body: AsyncView<Organization>(
        load: repo.organization,
        builder: (context, org) {
          _populateForm(org);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeroCard(org),
              const SizedBox(height: 16),
              _buildOrgFormCard(),
              const SizedBox(height: 16),
              _buildUnitsCard(repo),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(Organization org) {
    final name = org.name.isNotEmpty ? org.name : 'Organização';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'O';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        org.planLabel,
                        style: const TextStyle(
                          color: AppColors.brandText,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  org.cnpj != null && org.cnpj!.isNotEmpty
                      ? 'CNPJ: ${org.cnpj}'
                      : 'Identidade corporativa',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dados da empresa',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Identificação do workspace em documentos e relatórios.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Razão social / Nome *',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Informe a razão social.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cnpjController,
              decoration: const InputDecoration(
                labelText: 'CNPJ',
                hintText: '00.000.000/0000-00',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Endereço completo'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _saveOrganization,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SALVAR DADOS DA EMPRESA'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsCard(AccountRepository repo) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filiais e Unidades',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Estrutura organizacional',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _openNewUnitDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova filial'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(60, 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AsyncView<List<OrgUnit>>(
            shrinkWrap: true,
            key: ValueKey(_revision),
            load: repo.units,
            builder: (context, units) {
              if (units.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Nenhuma filial cadastrada.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: units.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final unit = units[index];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              unit.code,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        tooltip: 'Excluir unidade',
                        onPressed: () => _deleteUnit(unit),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
