import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:text_app/editusers.dart';
import 'package:text_app/viewinfo.dart';


class SerchPage extends StatefulWidget {
  const SerchPage({super.key});
  @override
  State<SerchPage> createState() => _SerchPageState();
}

class _SerchPageState extends State<SerchPage> {

  List<QueryDocumentSnapshot> data = [];
  bool isLoading = true;
  Map<String, bool> copiedUsers = {};
  bool showButtons = false;
  List<DateTime> selectedDates = [];
  bool isLoadingScan = false;
  TextEditingController searchController = TextEditingController();
  List<DocumentSnapshot> allUsers = [];
  // ignore: unused_field
  late Future<QuerySnapshot> _futureUsers;
  List<DocumentSnapshot> filteredUsers = [];
  bool isSearching = false;

  void fetchUsers() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      allUsers = snapshot.docs;
      // filteredUsers = allUsers;
    });
  }

  void searchUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredUsers = [];
      } else {
        filteredUsers = allUsers.where((user) {
          String name = user['name'].toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void onSearchTap() {
    setState(() {
      isSearching = true;
      filteredUsers = []; 
    });
  }

  void onSearchCancel() {
    FocusScope.of(context).unfocus();
    setState(() {
      searchController.clear();
      isSearching = false; 
      filteredUsers = allUsers;
    });
    Navigator.of(context).pushNamedAndRemoveUntil("homepage", (context) => false);
  }

  void copyText(String id) {
    Clipboard.setData(ClipboardData(text: id));
    setState(() {
      copiedUsers[id] = true;
    });
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        copiedUsers[id] = false;
      });
    });
  }

  getData () async{
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('users').get();  
    data.addAll(querySnapshot.docs);
    isLoading = false;
    setState(() {
      
    });
  }

  @override
  void initState() {
    getData();
    _futureUsers = FirebaseFirestore.instance.collection("users").get();
    super.initState();
    fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Search Users",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search by name...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        onPressed: onSearchCancel,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: searchUsers,
              onTap: onSearchTap,
            ),
          ),

          // User List
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No users found",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Try searching with a different name",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      var user = filteredUsers[index];
                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onLongPress: () {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.warning,
                              animType: AnimType.rightSlide,
                              title: "Warning",
                              desc: "What do you want to do?",
                              btnOkText: "Edit",
                              btnOkColor: Colors.blue,
                              btnOkOnPress: () async {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EditUsers(
                                      docid: user.id,
                                      oldname: user["name"],
                                    ),
                                  ),
                                );
                              },
                              btnCancelText: "Delete",
                              btnCancelColor: Colors.red,
                              btnCancelOnPress: () async {
                                await FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(user["qr"])
                                    .delete();
                                Navigator.of(context)
                                    .pushReplacementNamed("homepage");
                              },
                            ).show();
                          },
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ViewInfo(
                                  username: user["name"],
                                  userId: user["qr"],
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: Icon(
                                    Icons.person_outline,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user["name"],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        user["qr"],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    copyText(user["qr"]);
                                  },
                                  icon: Icon(
                                    copiedUsers[user["qr"]] == true
                                        ? Icons.check_circle
                                        : Icons.copy_outlined,
                                    color: copiedUsers[user["qr"]] == true
                                        ? Colors.green
                                        : Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
