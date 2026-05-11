import 'package:flutter/material.dart';

class TaskInputScreen extends StatefulWidget {
  const TaskInputScreen({super.key});

  @override
  State<TaskInputScreen> createState() => _TaskInputScreenState();
}

class _TaskInputScreenState extends State<TaskInputScreen> {
  final TextEditingController _textController = TextEditingController();
  final int maxChars = 250;


  @override
  Future<void> dispose() async {
    _textController.dispose();  // Dispose the controller here
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              "Text Input",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "RingTask App",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black45),
            onPressed: () {},
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              child: TextField(
                controller: _textController,
                maxLength: maxChars,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Type your task or note here...",
                  border: InputBorder.none,
                  counterText: "",
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (text) => setState(() {}),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${_textController.text.length} / $maxChars characters",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 30),
            // Microphone Button
            Column(
              children: [
                Material(
                  shape: const CircleBorder(),
                  color: Colors.blueAccent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      // TODO: Implement voice recording logic
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(28.0),
                      child: Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tap to record",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Icons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: () {
                    // TODO: Implement edit
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.grey),
                  onPressed: () {
                    // TODO: Implement play (TTS)
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _textController.clear();
                    });
                  },
                ),
              ],
            ),
            const Spacer(),
            // Save Task Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  // TODO: Save logic
                },
                child: const Text(
                  "Save Task",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "You can type, edit, or record tasks before saving.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
