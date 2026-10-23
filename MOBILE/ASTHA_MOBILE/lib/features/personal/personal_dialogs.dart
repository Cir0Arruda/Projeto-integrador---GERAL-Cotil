// ============================================================================
// ★ JANELAS MODAIS E DIÁLOGOS PESSOAIS (PERSONAL_DIALOGS.DART) ★
// Todos os formulários popups para gerenciar espaços e pertences:
// 1) SpaceFormDialog: Criação e edição de cômodos (largura, profundidade, tipo) :3
// 2) ObjectFormDialog: Cadastro de armários, gaveteiros e móveis (✿◠‿◠)
// 3) BelongingFormDialog: Cadastro e fotos de pertences guardados! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';

// Diálogo modal para criar ou editar um cômodo/espaço :3
class SpaceFormDialog extends StatefulWidget {
  const SpaceFormDialog({super.key, this.space});

  final PersonalSpace? space;

  @override
  State<SpaceFormDialog> createState() => _SpaceFormDialogState();
}

class _SpaceFormDialogState extends State<SpaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _width = TextEditingController();
  final _depth = TextEditingController();
  String _selectedTemplate = 'office';

  @override
  void initState() {
    super.initState();
    if (widget.space != null) {
      _name.text = widget.space!.name;
      _width.text = widget.space!.width.toString();
      _depth.text = widget.space!.depth.toString();
    } else {
      _name.text = 'Meu escritório';
      _width.text = '6.0';
      _depth.text = '5.0';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _depth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.space != null;
    return AlertDialog(
      title: Text(isEditing ? 'Medidas e nome do espaço' : 'Criar espaço'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome do espaço'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              if (!isEditing) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedTemplate,
                  decoration: const InputDecoration(
                    labelText: 'Começar com template',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'office',
                      child: Text('Escritório'),
                    ),
                    DropdownMenuItem(value: 'bedroom', child: Text('Quarto')),
                    DropdownMenuItem(
                      value: 'living',
                      child: Text('Sala de estar'),
                    ),
                    DropdownMenuItem(value: 'kitchen', child: Text('Cozinha')),
                    DropdownMenuItem(
                      value: 'empty',
                      child: Text('Espaço vazio'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedTemplate = v ?? 'office'),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Largura (m)',
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val < 2 || val > 50) {
                          return 'Entre 2 e 50';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _depth,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Profundidade (m)',
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val < 2 || val > 50) {
                          return 'Entre 2 e 50';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'name': _name.text.trim(),
              'width': double.parse(_width.text),
              'depth': double.parse(_depth.text),
              'template': _selectedTemplate,
            });
          },
          child: Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}

class LibraryDialog extends StatefulWidget {
  const LibraryDialog({super.key});

  @override
  State<LibraryDialog> createState() => _LibraryDialogState();
}

class _LibraryDialogState extends State<LibraryDialog> {
  final _search = TextEditingController();
  String _category = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase().trim();
    final filtered = PersonalCatalog.models.where((m) {
      if (_category.isNotEmpty && m.category != _category) return false;
      if (query.isNotEmpty && !m.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Biblioteca de Objetos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar na biblioteca...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Todas'),
                      selected: _category.isEmpty,
                      onSelected: (_) => setState(() => _category = ''),
                    ),
                    const SizedBox(width: 8),
                    ...PersonalCatalog.categories.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nenhum objeto encontrado.'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(m),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: _colorFromHex(m.color),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.weekend_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${m.width} × ${m.depth} × ${m.height} m',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompartmentsDialog extends StatefulWidget {
  const CompartmentsDialog({
    super.key,
    required this.objectName,
    required this.compartments,
  });

  final String objectName;
  final List<PersonalCompartment> compartments;

  @override
  State<CompartmentsDialog> createState() => _CompartmentsDialogState();
}

class _CompartmentsDialogState extends State<CompartmentsDialog> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.compartments
        .map((c) => TextEditingController(text: c.name))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (_controllers.length >= 20) return;
    setState(() {
      _controllers.add(TextEditingController(text: 'Novo local'));
    });
  }

  void _remove(int idx) {
    setState(() {
      _controllers[idx].dispose();
      _controllers.removeAt(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Locais em ${widget.objectName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Crie gavetas, prateleiras ou áreas específicas para organizar seus pertences.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _controllers.isEmpty
                  ? const Center(
                      child: Text('Nenhum compartimento cadastrado.'),
                    )
                  : ListView.builder(
                      itemCount: _controllers.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controllers[i],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Ex.: Gaveta superior',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _remove(i),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _controllers.length < 20 ? _add : null,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar local'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final result = <PersonalCompartment>[];
            for (int i = 0; i < _controllers.length; i++) {
              final text = _controllers[i].text.trim();
              if (text.isNotEmpty) {
                final id = i < widget.compartments.length
                    ? widget.compartments[i].id
                    : 'comp_${DateTime.now().millisecondsSinceEpoch}_$i';
                result.add(PersonalCompartment(id: id, name: text));
              }
            }
            Navigator.of(context).pop(result);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class BelongingFormDialog extends StatefulWidget {
  const BelongingFormDialog({
    super.key,
    this.item,
    required this.spaces,
    this.initialSpaceId,
    this.initialObjectId,
    this.initialCompartmentId,
  });

  final PersonalBelonging? item;
  final List<PersonalSpace> spaces;
  final int? initialSpaceId;
  final String? initialObjectId;
  final String? initialCompartmentId;

  @override
  State<BelongingFormDialog> createState() => _BelongingFormDialogState();
}

class _BelongingFormDialogState extends State<BelongingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _tags = TextEditingController();

  int? _selectedSpaceId;
  String? _selectedObjectId;
  String? _selectedCompartmentId;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _name.text = widget.item!.name;
      _notes.text = widget.item!.notes ?? '';
      _tags.text = widget.item!.tags ?? '';
      _selectedSpaceId = widget.item!.spaceId ?? widget.initialSpaceId;
      _selectedObjectId = widget.item!.objectId ?? widget.initialObjectId;
      _selectedCompartmentId =
          widget.item!.compartmentId ?? widget.initialCompartmentId;
    } else {
      _selectedSpaceId =
          widget.initialSpaceId ??
          (widget.spaces.isNotEmpty ? widget.spaces.first.id : null);
      _selectedObjectId = widget.initialObjectId;
      _selectedCompartmentId = widget.initialCompartmentId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSpaces = widget.spaces.where((s) => !s.archived).toList();
    final currentSpace = activeSpaces
        .where((s) => s.id == _selectedSpaceId)
        .firstOrNull;
    final objects = currentSpace?.objects ?? const <PersonalObject>[];
    final currentObject = objects
        .where((o) => o.id == _selectedObjectId)
        .firstOrNull;
    final compartments =
        currentObject?.compartments ?? const <PersonalCompartment>[];

    return AlertDialog(
      title: Text(
        widget.item != null ? 'Editar pertence' : 'Cadastrar pertence',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nome do pertence *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Descrição / características',
                    hintText: 'Ex.: Carregador USB-C branco de 20W',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: 'Palavras para encontrar',
                    hintText: 'Ex.: eletrônicos, cabos, trabalho',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _selectedSpaceId,
                  decoration: const InputDecoration(labelText: 'Espaço'),
                  items: activeSpaces
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSpaceId = val;
                      _selectedObjectId = null;
                      _selectedCompartmentId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  key: ValueKey('obj_${_selectedSpaceId}_$_selectedObjectId'),
                  initialValue: _selectedObjectId,
                  decoration: const InputDecoration(labelText: 'Móvel'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem móvel definido'),
                    ),
                    ...objects.map(
                      (o) => DropdownMenuItem(value: o.id, child: Text(o.name)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedObjectId = val;
                      _selectedCompartmentId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  key: ValueKey(
                    'comp_${_selectedObjectId}_$_selectedCompartmentId',
                  ),
                  initialValue: _selectedCompartmentId,
                  decoration: const InputDecoration(
                    labelText: 'Gaveta ou subdivisão',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem subdivisão'),
                    ),
                    ...compartments.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedCompartmentId = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'name': _name.text.trim(),
              'notes': _notes.text.trim(),
              'tags': _tags.text.trim(),
              'spaceId': _selectedSpaceId,
              'objectId': _selectedObjectId,
              'compartmentId': _selectedCompartmentId,
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    super.key,
    this.task,
    required this.spaces,
    this.initialSpaceId,
    this.initialObjectId,
  });

  final PersonalTask? task;
  final List<PersonalSpace> spaces;
  final int? initialSpaceId;
  final String? initialObjectId;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _due = TextEditingController();
  String _priority = 'normal';
  String _recurrence = 'none';
  int? _selectedSpaceId;
  String? _selectedObjectId;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _title.text = widget.task!.title;
      _due.text = widget.task!.due;
      _priority = widget.task!.priority;
      _recurrence = widget.task!.recurrence;
      _selectedSpaceId = widget.task!.spaceId ?? widget.initialSpaceId;
      _selectedObjectId = widget.task!.objectId ?? widget.initialObjectId;
    } else {
      _selectedSpaceId =
          widget.initialSpaceId ??
          (widget.spaces.isNotEmpty ? widget.spaces.first.id : null);
      _selectedObjectId = widget.initialObjectId;
      final now = DateTime.now().add(const Duration(hours: 1));
      _due.text = now.toIso8601String().substring(0, 16);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _due.text = dt.toIso8601String().substring(0, 16);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSpaces = widget.spaces.where((s) => !s.archived).toList();
    final currentSpace = activeSpaces
        .where((s) => s.id == _selectedSpaceId)
        .firstOrNull;
    final objects = currentSpace?.objects ?? const <PersonalObject>[];

    return AlertDialog(
      title: Text(widget.task != null ? 'Editar tarefa' : 'Agendar tarefa'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'O que você quer fazer? *',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a tarefa'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _selectedSpaceId,
                  decoration: const InputDecoration(labelText: 'Espaço *'),
                  items: activeSpaces
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSpaceId = val;
                      _selectedObjectId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  key: ValueKey(
                    'task_obj_${_selectedSpaceId}_$_selectedObjectId',
                  ),
                  initialValue: _selectedObjectId,
                  decoration: const InputDecoration(
                    labelText: 'Objeto (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem objeto específico'),
                    ),
                    ...objects.map(
                      (o) => DropdownMenuItem(value: o.id, child: Text(o.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedObjectId = val),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _due,
                  readOnly: true,
                  onTap: _pickDateTime,
                  decoration: const InputDecoration(
                    labelText: 'Data e horário *',
                    suffixIcon: Icon(Icons.access_time),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Prioridade',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('Alta')),
                          DropdownMenuItem(value: 'low', child: Text('Baixa')),
                        ],
                        onChanged: (v) =>
                            setState(() => _priority = v ?? 'normal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _recurrence,
                        decoration: const InputDecoration(labelText: 'Repetir'),
                        items: const [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('Não repetir'),
                          ),
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Diariamente'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Semanalmente'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Mensalmente'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _recurrence = v ?? 'none'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'title': _title.text.trim(),
              'due': _due.text,
              'spaceId': _selectedSpaceId,
              'objectId': _selectedObjectId,
              'priority': _priority,
              'recurrence': _recurrence,
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class PersonalFinderDialog extends StatefulWidget {
  const PersonalFinderDialog({super.key, required this.repo});

  final PersonalRepository repo;

  @override
  State<PersonalFinderDialog> createState() => _PersonalFinderDialogState();
}

class _PersonalFinderDialogState extends State<PersonalFinderDialog> {
  final _query = TextEditingController();
  bool _busy = false;
  PersonalFindAnswer? _answer;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });
    try {
      final res = await widget.repo.findBelongings(text);
      if (mounted) setState(() => _answer = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_alt_outlined,
                    color: AppColors.brand,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Onde deixei? (IA ASTHA)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pergunte sobre seus pertences. A busca analisa seus registros e indica a localização exata.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'Ex.: Onde deixei o passaporte?',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _search,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Buscar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              if (_answer != null) ...[
                if (_answer!.notice.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _answer!.notice,
                      style: const TextStyle(
                        color: AppColors.brandText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_answer!.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _answer!.message,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  child: _answer!.results.isEmpty
                      ? const Center(
                          child: Text('Nenhum registro correspondente.'),
                        )
                      : ListView.separated(
                          itemCount: _answer!.results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final item = _answer!.results[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.brandLight,
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                item.locationLabel ??
                                    (item.spaceName ?? 'Sem local salvo'),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                item.lastConfirmedAt != null
                                    ? 'Confirmado'
                                    : '',
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ] else if (!_busy)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Digite sua pergunta para localizar um item.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFFC9B7A2);
  }
}
