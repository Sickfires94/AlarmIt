import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WeekdaysPicker extends StatefulWidget {
  final List<bool> initialSelectedDays;
  final Function(List<bool>) onSelectionChanged;

  const WeekdaysPicker({
    Key? key,
    required this.initialSelectedDays,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<WeekdaysPicker> createState() => _WeekdaysPickerState();
}

class _WeekdaysPickerState extends State<WeekdaysPicker> {
  List<bool> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    _selectedDays = List.from(widget.initialSelectedDays);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final weekday = index + 1; // 1-based index for weekdays
        final isSelected = _selectedDays[index + 1];


        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDays[index + 1] = !isSelected;
              print(_selectedDays);
            });
            widget.onSelectionChanged(_selectedDays);
          },
          child: Container(
            margin: EdgeInsets.all(2),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.green : Colors.redAccent,
            ),
            child: Center(
              child: Text(
                getWeekdayAbbreviation(weekday),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  String getWeekdayAbbreviation(int weekday) {
    switch (weekday) {
      // case 0:
      //   return 'Sun';
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thur';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}