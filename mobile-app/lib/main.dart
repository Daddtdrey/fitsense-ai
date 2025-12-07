import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FitSenseApp());
}

class FitSenseApp extends StatelessWidget {
  const FitSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitSense AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Uint8List> _closetItems = [];
  
  // --- MONETIZATION VARIABLES ---
  int _trialsUsed = 0;
  bool _isPremium = false;
  Uint8List? _suggestedTop;
  Uint8List? _suggestedBottom;

  // --- STORE DATA (Fixed with Web-Safe URLs) ---
  final List<Map<String, String>> _storeItems = [
    {
      "name": "Classic Denim Jacket",
      "price": "\$120",
      "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/M65_jacket.jpg/320px-M65_jacket.jpg"
    },
    {
      "name": "Summer Fedora",
      "price": "\$45",
      "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/A_fedora_hat.jpg/320px-A_fedora_hat.jpg"
    },
    {
      "name": "Canvas Sneakers",
      "price": "\$89",
      "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Converse_sneakers.JPG/320px-Converse_sneakers.JPG"
    },
    {
      "name": "Leather Handbag",
      "price": "\$250",
      "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Handbag.jpg/320px-Handbag.jpg"
    },
    {
      "name": "Blue T-Shirt",
      "price": "\$25",
      "image": "https://upload.wikimedia.org/wikipedia/commons/2/24/Blue_T-shirt.jpg"
    },
  ];

  // --- THIS IS THE MISSING FUNCTION ---
  void _addToCloset(Uint8List imageBytes) {
    setState(() {
      _closetItems.add(imageBytes);
      _currentIndex = 0; // Go back to closet view
    });
  }

  // --- THE ALGORITHM & PAYWALL ---
  void _generateOutfit() {
    if (_closetItems.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least 2 items first!")));
      return;
    }

    // 1. CHECK PAYWALL
    if (!_isPremium && _trialsUsed >= 5) {
      _showPaywall();
      return;
    }

    // 2. GENERATE OUTFIT
    setState(() {
      final random = Random();
      _suggestedTop = _closetItems[random.nextInt(_closetItems.length)];
      _suggestedBottom = _closetItems[random.nextInt(_closetItems.length)];
      
      if (!_isPremium) _trialsUsed++; 
    });
  }

  void _showPaywall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("TRIAL ENDED 🔒"),
        content: const Text("You have used your 5 free AI styles.\n\nUpgrade to Premium to generate unlimited outfits."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              setState(() => _isPremium = true); // Simulate Payment
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Welcome to Premium! 👑")));
            },
            child: const Text("Unlock (\$9.99)"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      ClosetGallery(items: _closetItems),
      AIProcessor(onSave: _addToCloset),
      StylistScreen(
        onGenerate: _generateOutfit,
        topImage: _suggestedTop,
        bottomImage: _suggestedBottom,
        trialsLeft: 5 - _trialsUsed,
        isPremium: _isPremium,
      ),
      ShoppingScreen(items: _storeItems),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Crucial for 4+ items
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Closet"),
          BottomNavigationBarItem(icon: Icon(Icons.add_a_photo_outlined), label: "Add"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "Stylist"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: "Shop"),
        ],
      ),
    );
  }
}

// SCREEN 1: GALLERY
class ClosetGallery extends StatelessWidget {
  final List<Uint8List> items;
  const ClosetGallery({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MY CLOSET", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2))),
      body: items.isEmpty
          ? const Center(child: Text("Your closet is empty.", style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: items.length,
              itemBuilder: (context, index) => Image.memory(items[index]),
            ),
    );
  }
}

// SCREEN 2: ADD ITEM
class AIProcessor extends StatefulWidget {
  final Function(Uint8List) onSave;
  const AIProcessor({super.key, required this.onSave});

  @override
  State<AIProcessor> createState() => _AIProcessorState();
}

class _AIProcessorState extends State<AIProcessor> {
  Uint8List? _cleanImage;
  bool _isLoading = false;

  Future<void> _pickAndProcess() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/clean-image'));
        request.files.add(http.MultipartFile.fromBytes('file', await image.readAsBytes(), filename: 'upload.jpg'));
        var response = await request.send();
        if (response.statusCode == 200) {
          final data = await response.stream.toBytes();
          setState(() => _cleanImage = data);
        }
      } catch (e) { print(e); } finally { setState(() => _isLoading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ADD ITEM")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             if (_isLoading) const CircularProgressIndicator(),
             if (_cleanImage != null) ...[
                Container(
                  height: 300, 
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), image: const DecorationImage(image: NetworkImage("https://www.transparenttextures.com/patterns/checkerboard-cross.png"), repeat: ImageRepeat.repeat)),
                  child: Image.memory(_cleanImage!)
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => widget.onSave(_cleanImage!), child: const Text("Save to Closet"))
             ] else if (!_isLoading) 
                ElevatedButton(onPressed: _pickAndProcess, child: const Text("Select Photo"))
          ],
        ),
      ),
    );
  }
}

// SCREEN 3: THE STYLIST
class StylistScreen extends StatelessWidget {
  final VoidCallback onGenerate;
  final Uint8List? topImage;
  final Uint8List? bottomImage;
  final int trialsLeft;
  final bool isPremium;

  const StylistScreen({super.key, required this.onGenerate, required this.topImage, required this.bottomImage, required this.trialsLeft, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI STYLIST"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Chip(
              label: Text(isPremium ? "PREMIUM" : "$trialsLeft FREE"),
              backgroundColor: isPremium ? Colors.amber : Colors.grey[200],
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network("https://cdn-icons-png.flaticon.com/512/3011/3011270.png", height: 400, color: Colors.grey[200]),
                  if (bottomImage != null) Positioned(bottom: 50, child: SizedBox(height: 200, child: Image.memory(bottomImage!))),
                  if (topImage != null) Positioned(top: 50, child: SizedBox(height: 200, child: Image.memory(topImage!))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("GENERATE OUTFIT"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// SCREEN 4: SHOPPING (With Error Handling)
class ShoppingScreen extends StatelessWidget {
  final List<Map<String, String>> items;
  const ShoppingScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SHOP THE LOOK")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("AI RECOMMENDED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Based on your closet style", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ...items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 15),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: SizedBox(
                width: 60,
                height: 60,
                child: Image.network(
                  item["image"]!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
              ),
              title: Text(item["name"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item["price"]!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              trailing: ElevatedButton(
                onPressed: () {}, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                child: const Text("BUY"),
              ),
            ),
          )),
        ],
      ),
    );
  }
}