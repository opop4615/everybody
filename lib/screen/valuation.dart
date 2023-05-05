import 'package:everyvaluation/firebase_options.dart';
import 'package:everyvaluation/model/ticker.dart';
import 'package:everyvaluation/util/hintcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class ValuationScreen extends StatefulWidget {
  _ValuationScreenState createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen> {
  @override
  void initState() {
    super.initState();
  }

  final TextEditingController _typeAheadController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(25, 7, 25, 7),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  height: 10,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "모두의\n밸류에이션",
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 25,
                      letterSpacing: -1.5),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  height: 5,
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '모두를 위한 주식 가치평가 어플리케이션',
                  style: TextStyle(
                      fontWeight: FontWeight.w100,
                      fontSize: 15,
                      letterSpacing: -1),
                )
              ],
            ),
            SizedBox(height: 15),
            Container(
              height: 40,
              padding: EdgeInsets.fromLTRB(25, 0, 25, 0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  Container(
                    child: Icon(
                      Icons.search,
                      color: Colors.grey[600],
                    ),
                  ),
                  Expanded(
                    child: TypeAheadField(
                      textFieldConfiguration: TextFieldConfiguration(
                        autofocus: false,
                        controller: _typeAheadController,
                        style: TextStyle(fontSize: 15, color: Colors.black),
                        decoration: InputDecoration(
                            enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.white, width: 0)),
                            border: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.white, width: 0)),
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.white, width: 0)),
                            contentPadding: EdgeInsets.fromLTRB(15, 5, 0, 0),
                            hintText: '종목명 혹은 티커를 입력하세요.'),
                      ),
                      suggestionsCallback: (pattern) async {
                        return await Tickers.getSuggestions(pattern);
                      },
                      itemBuilder: (context, Map<String, String> suggestion) {
                        return ListTile(
                          title: Text(
                            suggestion['Name']!,
                            style: TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            '${suggestion['Code']}',
                            style: TextStyle(fontSize: 8),
                          ),
                        );
                      },
                      onSuggestionSelected: (Map<String, String> suggestion) {
                        _typeAheadController.text = suggestion['Name']!;
                        // your implementation here
                      },
                      noItemsFoundBuilder: (value) {
                        var localizedMessage = "존재하지 않는 종목명 혹은 티커입니다.";
                        return Text(
                          localizedMessage,
                          style: TextStyle(fontSize: 15),
                        );
                      },
                      suggestionsBoxDecoration: SuggestionsBoxDecoration(
                          constraints: BoxConstraints(maxHeight: 160)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Hint for you',
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Container(
              height: 100,
              child: ListView.builder(
                itemCount: 4,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return HintCard(
                    valuationName: 'PER',
                    hintText: 'EPS / 주가',
                  ); //여기에 밸류에이션 방법 설명 넣기
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
