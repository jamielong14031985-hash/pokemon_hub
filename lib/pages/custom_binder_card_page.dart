import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/custom_binder_models.dart';
import '../models/tcg_card.dart';
import '../services/custom_binder_sync_service.dart';
import '../utils/auth_input_decoration.dart';
import '../utils/card_condition_helpers.dart';
import '../widgets/custom_binder_cover.dart';
import '../widgets/detail_tile.dart';
import '../widgets/set_logo_widgets.dart';

class CustomBinderCardPage extends StatefulWidget {
  const CustomBinderCardPage({
    super.key,
    required this.binder,
    required this.entry,
  });

  final CustomBinder binder;
  final CustomBinderCardEntry entry;

  @override
  State<CustomBinderCardPage> createState() => _CustomBinderCardPageState();
}

class _CustomBinderCardPageState extends State<CustomBinderCardPage> {
  late bool normal;
  late bool reverseHolo;
  late bool holo;
  late int copies;
  late String condition;
  late String gradingCompany;
  late final TextEditingController _binderGradeController;
  late final TextEditingController _binderConditionNotesController;
  bool _saving = false;
  bool _removing = false;

  TcgCard get _card => widget.entry.toSummaryCard();

  @override
  void initState() {
    super.initState();
    final ownership = widget.entry.ownership;
    normal = ownership.normal;
    reverseHolo = ownership.reverseHolo;
    holo = ownership.holo;
    copies = ownership.effectiveCopies;
    condition = normaliseCardCondition(ownership.condition);
    gradingCompany = ownership.gradingCompany.trim();
    _binderGradeController = TextEditingController(text: formatCardGrade(ownership.grade));
    _binderConditionNotesController = TextEditingController(text: ownership.conditionNotes);
  }

  @override
  void dispose() {
    _binderGradeController.dispose();
    _binderConditionNotesController.dispose();
    super.dispose();
  }

  double? _currentBinderGradeValue() {
    final raw = _binderGradeController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0 || value > 10) return null;
    return value;
  }

  Widget _buildBinderConditionEditor() {
    return Card(
      color: const Color(0xFF102754),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Condition & Grading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add raw condition, slab details, and notes for this binder copy.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: kCardConditionOptions.contains(condition) ? condition : kDefaultCardCondition,
              dropdownColor: const Color(0xFF16366E),
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Raw condition'),
              items: kCardConditionOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  condition = value ?? kDefaultCardCondition;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kGradingCompanyOptions.contains(gradingCompany) ? gradingCompany : 'Other',
              dropdownColor: const Color(0xFF16366E),
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Grading company'),
              items: kGradingCompanyOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option.isEmpty ? 'Not graded' : option),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  gradingCompany = value ?? '';
                  if (gradingCompany.isEmpty) {
                    _binderGradeController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _binderGradeController,
              enabled: gradingCompany.trim().isNotEmpty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Grade number')
                  .copyWith(
                    hintText: gradingCompany.trim().isEmpty ? 'Choose a grading company first' : 'e.g. 9, 9.5 or 10',
                    hintStyle: const TextStyle(color: Colors.white38),
                    helperText: 'Grades are saved from 1 to 10.',
                    helperStyle: const TextStyle(color: Colors.white54),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _binderConditionNotesController,
              maxLines: 3,
              maxLength: 220,
              style: const TextStyle(color: Colors.white),
              decoration: authInputDecoration('Condition notes')
                  .copyWith(
                    hintText: 'e.g. small whitening on back corner',
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterStyle: const TextStyle(color: Colors.white54),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      await CustomBinderSyncService.saveCardEntry(
        binderId: widget.binder.id,
        entry: widget.entry.copyWith(
          normal: normal,
          reverseHolo: reverseHolo,
          holo: holo,
          copies: math.max(1, copies),
          condition: condition,
          gradingCompany: gradingCompany,
          grade: _currentBinderGradeValue(),
          clearGrade: _currentBinderGradeValue() == null,
          conditionNotes: _binderConditionNotesController.text.trim(),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _remove() async {
    if (_removing) return;
    setState(() {
      _removing = true;
    });
    try {
      await CustomBinderSyncService.removeCardFromBinder(
        binderId: widget.binder.id,
        cardId: widget.entry.cardId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _removing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CustomBinderCover(
                            imageBase64: widget.binder.imageBase64,
                            size: 62,
                            borderRadius: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.binder.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Custom Binder',
                                  style: TextStyle(color: Color(0xFFD8E3FB)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SetLogoTile(setId: card.setId, setName: card.setName, logoUrl: card.setLogoUrl),
                  if (card.largeImageUrl != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBECBE1), Color(0xFF879CC4)],
                        ),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(card.largeImageUrl!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DetailTile(label: 'Set', value: card.setName),
                  DetailTile(label: 'Card Number', value: card.number),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: normal,
                          onChanged: (value) => setState(() => normal = value),
                          title: const Text('Normal', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: reverseHolo,
                          onChanged: (value) => setState(() => reverseHolo = value),
                          title: const Text('Reverse Holo', style: TextStyle(color: Colors.white)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        SwitchListTile(
                          value: holo,
                          onChanged: (value) => setState(() => holo = value),
                          title: const Text('Holo', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF102754),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Copies in Custom Binder',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: copies > 1
                                      ? () {
                                          setState(() {
                                            copies--;
                                          });
                                        }
                                      : null,
                                  child: const Text('- Remove'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 72,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$copies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      copies++;
                                    });
                                  },
                                  child: const Text('+ Add'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBinderConditionEditor(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _removing ? null : _remove,
                      icon: _removing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      label: const Text('Remove from Custom Binder'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
