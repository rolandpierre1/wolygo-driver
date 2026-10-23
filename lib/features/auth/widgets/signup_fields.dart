import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

String sxT(String fr, String en) => (Get.locale?.languageCode ?? 'fr') == 'fr' ? fr : en;

BoxDecoration sxBox(BuildContext context) => BoxDecoration(
  color: Theme.of(context).cardColor,
  borderRadius: BorderRadius.circular(50),
  border: Border.all(width: .5, color: Theme.of(context).hintColor.withOpacity(.7)),
);

Widget sxLabel(String text) => Padding(
  padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault, bottom: Dimensions.paddingSizeExtraSmall),
  child: Text(text, style: textMedium),
);

/// Champ texte arrondi avec titre.
class SxField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType type;
  final TextCapitalization caps;
  const SxField(this.label, this.controller, {super.key, this.type = TextInputType.text, this.caps = TextCapitalization.none});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sxLabel(label),
      Container(
        decoration: sxBox(context),
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
        child: TextField(controller: controller, keyboardType: type, textCapitalization: caps,
          decoration: const InputDecoration(border: InputBorder.none)),
      ),
    ]);
  }
}

/// Sélecteur de date (aaaa-mm-jj).
class SxDate extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool future;
  final VoidCallback onChanged;
  const SxDate(this.label, this.controller, {super.key, required this.onChanged, this.future = false});
  @override
  Widget build(BuildContext context) {
    final empty = controller.text.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sxLabel(label),
      InkWell(
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: future ? now.add(const Duration(days: 365)) : DateTime(now.year - 30, 1, 1),
            firstDate: future ? now : DateTime(1930),
            lastDate: future ? now.add(const Duration(days: 365 * 15)) : now,
          );
          if (d != null) {
            controller.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            onChanged();
          }
        },
        child: Container(
          height: 50, width: double.infinity, alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          decoration: sxBox(context),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 10),
            Text(empty ? sxT('Choisir une date', 'Choose a date') : controller.text,
              style: textRegular.copyWith(color: empty ? Theme.of(context).hintColor : null)),
          ]),
        ),
      ),
    ]);
  }
}

/// Liste déroulante arrondie avec titre.
class SxDrop<T> extends StatelessWidget {
  final String label, hint;
  final T? value;
  final List<T> items;
  final String Function(T) text;
  final void Function(T?) onChanged;
  const SxDrop(this.label, {super.key, required this.hint, required this.value, required this.items,
    required this.text, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sxLabel(label),
      Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
        decoration: sxBox(context),
        child: DropdownButton<T>(
          value: value, isExpanded: true, underline: const SizedBox(),
          hint: Text(hint, style: textRegular.copyWith(color: Theme.of(context).hintColor)),
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(text(e)))).toList(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}

/// Carte « document » : choisir une photo + date d'expiration optionnelle.
class SxDoc extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onPick, onRemove;
  final Widget? expiry;
  const SxDoc(this.label, {super.key, required this.file, required this.onPick, required this.onRemove, this.expiry});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).hintColor.withOpacity(.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: textMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          child: Container(
            height: 54, width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).hintColor.withOpacity(.6))),
            child: Row(children: [
              if (file != null)
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(file!.path), width: 40, height: 40, fit: BoxFit.cover))
              else
                Icon(Icons.upload_file, color: Theme.of(context).hintColor),
              const SizedBox(width: 10),
              Expanded(child: Text(file == null ? sxT('Sélectionner un fichier', 'Select a file') : file!.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(color: Theme.of(context).hintColor))),
              if (file != null)
                InkWell(onTap: onRemove, child: const Icon(Icons.delete_forever_rounded, color: Colors.red)),
            ]),
          ),
        ),
        if (expiry != null) expiry!,
      ]),
    );
  }
}
