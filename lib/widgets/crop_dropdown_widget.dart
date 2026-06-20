// lib/widgets/crop_dropdown_widget.dart (Optional - reusable widget)
import 'package:flutter/material.dart';

class CropDropdownWidget extends StatelessWidget {
  final List<Map<String, dynamic>> crops;
  final String selectedCropId;
  final ValueChanged<String> onChanged;
  final String label;

  const CropDropdownWidget({
    super.key,
    required this.crops,
    required this.selectedCropId,
    required this.onChanged,
    this.label = 'Select Crop',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Main: ${_getMainCropName()}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCropId.isEmpty ? null : selectedCropId,
              isExpanded: true,
              hint: const Text('Select Crop'),
              items: crops.map((crop) {
                final isMain = crop['crop_type'] == 'main';
                return DropdownMenuItem<String>(
                  value: crop['crop_id'] as String,
                  child: Row(
                    children: [
                      if (isMain)
                        Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                      if (!isMain)
                        Icon(Icons.grass, size: 14, color: Colors.green.shade400),
                      const SizedBox(width: 8),
                      Text(crop['name']),
                      if (isMain)
                        const SizedBox(width: 8),
                      if (isMain)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Main',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getMainCropName() {
    for (var crop in crops) {
      if (crop['crop_type'] == 'main') {
        return crop['name'];
      }
    }
    return crops.isNotEmpty ? crops.first['name'] : 'None';
  }
}