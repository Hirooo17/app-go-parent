import 'package:flutter/material.dart';
import 'package:go_parent/services/database/local/helpers/baby_helper.dart';
import 'package:go_parent/services/database/local/helpers/missions_helper.dart';
import 'package:go_parent/services/database/local/helpers/pictures_helper.dart';
import 'package:go_parent/services/database/local/helpers/user_mission_helper.dart';
import 'package:go_parent/services/database/local/models/baby_model.dart';
import 'package:go_parent/services/database/local/models/missions_model.dart';
import 'package:go_parent/services/database/local/sqlite.dart';
import 'package:go_parent/utilities/constants.dart';
import 'package:go_parent/utilities/mission_report.dart';
import 'package:go_parent/utilities/user_session.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:go_parent/screens/mission_page/mission_brain.dart';

  enum MissionCategory {
  Social,
  Creative,
  Physical,
  Math,
}


class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});
  static String id = "mission_screen";

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  late MissionBrain _missionBrain;

  bool _isLoading = true;
  double progress = 0;
  int totalPoints = 0;

  int? _selectedBabyAge;
  String? _selectedBabyName;
  String? photoPath;

  List<DropdownMenuEntry<int>> dropdownItems = [];
  List<MissionWithStatus> _missions = [];

  @override
  void initState() {
    super.initState();
    _initializeMissionBrain();
  }


  Future<void> _initializeMissionBrain() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbService = DatabaseService.instance;
    final db = await dbService.database;

    final missionHelper = MissionHelper(db);
    final pictureHelper = PictureHelper(db);
    final babyHelper = BabyHelper(db);
    final userMissionHelper = UserMissionHelper(db);

    _missionBrain = MissionBrain(missionHelper, babyHelper, pictureHelper, userMissionHelper);

    await _loadMissions();
    await  _fetchBabiesAndSetupDropdown();
  }


  Future<void> _fetchBabiesAndSetupDropdown() async {
    setState(() => _isLoading = true);

    try {
      List<BabyModel> babies = await _missionBrain.getBabiesForUser();
      if (babies.isEmpty) {
        print("No babies found for user");
        setState(() {
          dropdownItems = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        dropdownItems = babies
            .map((baby) => DropdownMenuEntry<int>(
                  value: baby.babyAge,
                  label: baby.babyName,
                ))
            .toList();
        // Set initial selected age
        _selectedBabyAge = babies.first.babyAge;
        _selectedBabyName = babies.first.babyName;
      });

      // Fetch initial missions
      await _fetchMissions();

    } catch (e) {
      print('Error setting up dropdown: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _fetchMissions() async {
    if (_selectedBabyAge == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. First fetch all missions for the age
      List<MissionModel> ageMissions = await _missionBrain.getMissionsByAge(_selectedBabyAge!);

      // 2. Get current user's completed missions
      final userId = UserSession().userId;
      final completedMissions = await _missionBrain.userMissionHelper.getUserCompletedMissions(userId!);

      // 3. Create MissionWithStatus objects
      final missionsWithStatus = ageMissions.map((mission) =>
        MissionWithStatus(
          mission: mission,
          isCompleted: completedMissions.contains(mission.missionId)
        )
      ).toList();

      setState(() {
        _missions = missionsWithStatus;
      });
    } catch (e) {
      print('Error fetching missions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _missionBrain.loadAllMissions();
      print("Missions loaded successfully");
    } catch (e) {
      print("Error loading missions: $e");
    }

    setState(() {
      _isLoading = false;
    });
  }



  //pinapaadd ni maam

  final TextEditingController _missionController = TextEditingController();

  void _showOptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mission Report'),
          content: TextField(
            controller: _missionController,
            decoration: InputDecoration(
              hintText: 'Any place, song, video, call, tool, or person...',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                // Save the mission report
                MissionReport.instance.addReport(_missionController.text);
                _missionController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [

              Expanded(
                child: DefaultTabController(
                  length: 1,
                  child: Scaffold(
                    backgroundColor: Colors.grey[200],
                    appBar: AppBar(
                      elevation: 8,
                      automaticallyImplyLeading: false,
                      backgroundColor: Colors.teal,
                      title: const Text('Go Missions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),

                      bottom:  TabBar(

                        tabs: [
                          Tab(text: 'All Missions',  ),
                          // Tab(text: 'Social Missions', ),
                          // Tab(text: 'Creative Missions', ),
                          // Tab(text: 'Physical Missions', ),
                          // Tab(text: 'Math Missions'),
                        ], labelColor: Colors.white,
                            unselectedLabelColor: Colors.white,
                            indicator: BoxDecoration(
                            //  color: Colors.lightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),),



                      actions: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: SizedBox(
                            width: 250,
                            child: Card(
                              color: colorbeige,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Tooltip(
                                  message: "Change Current Baby To Change Missions",
                                  child: DropdownButton<int>(
                                    dropdownColor: colorbeige,
                                    value: _selectedBabyAge,
                                    items: dropdownItems
                                        .map((item) => DropdownMenuItem<int>(
                                              value: item.value,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      SizedBox(width: 4,),
                                                      Icon(
                                                        Icons.child_care,
                                                        color: Colors.black,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        item.label,
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Icon(
                                                    Icons.arrow_drop_down,
                                                    color: Colors.black,
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (int? age) async {
                                      setState(() {
                                        _selectedBabyAge = age;
                                        _selectedBabyName = dropdownItems
                                            .firstWhere((item) => item.value == age)
                                            .label;
                                      });
                                      await _fetchMissions();
                                      // Show RFlutter Alert
                                      final firstBabyName = _selectedBabyName;
                                      Alert(
                                        context: context,
                                        type: AlertType.success,
                                        title: "Missions Updated Successfully!",
                                        desc: "Loaded missions curated for baby $firstBabyName.",
                                        buttons: [
                                          DialogButton(
                                            child: Text(
                                              "OK",
                                              style: TextStyle(color: Colors.white, fontSize: 18),
                                            ),
                                            onPressed: () => Navigator.pop(context),
                                            width: 120,
                                          )
                                        ],
                                      ).show();
                                    },
                                    style: const TextStyle(color: Colors.black),
                                    iconEnabledColor: Colors.black,
                                    isExpanded: true,
                                    underline: SizedBox(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )

                      ],
                    ),
                    body: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          Column(
                            children: [

                              SizedBox(height: 30,),


                              Expanded(

                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.15),
                                  child: ListView.builder(
                                      itemCount: _missions.length,
                                      itemBuilder: (context, index) {
                                        final missionWithStatus = _missions[index];
                                        final mission = missionWithStatus.mission;

                                        return Card(

                                          elevation: 6,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          margin: const EdgeInsets.all(10.0),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [

                                                ListTile(
                                                  title: Text(
                                                    mission.title,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),

                                                  subtitle: Text(
                                                    mission.content,
                                                    style: const TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  trailing: Tooltip(
                                                    message: "Current Status of this Mission.",
                                                    child: Icon(
                                                      missionWithStatus.isCompleted
                                                          ? Icons.check_circle
                                                          : Icons.circle_outlined,
                                                      color: missionWithStatus.isCompleted
                                                          ? Colors.green
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),

                                                if (!missionWithStatus.isCompleted) ...[
                                                  const SizedBox(width: 10),
                                                  SizedBox(
                                                    width: 180,
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.teal,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                      onPressed: () async {
                                                        if (mission.missionId != null) {
                                                           _showOptionDialog();

                                                           
                                                          await _missionBrain.completeMissionWithPhoto(context, mission.missionId!);





                                                          await _fetchMissions();
                                                        }
                                                      },
                                                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                                                      label: const Text('Submit Photo', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  )

                                                ] else ...[
                                                  const SizedBox(width: 10),
                                                  SizedBox(
                                                    width: 180,
                                                    child: Tooltip(
                                                      message: "You can submit another photo to further commemorate this mission!",
                                                      child: ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                        onPressed: () async {
                                                          if (mission.missionId != null) {
                                                            await _missionBrain.completeMissionWithPhoto(context, mission.missionId!);
                                                            await _fetchMissions();
                                                          }
                                                        },
                                                        icon: const Icon(Icons.camera_alt, color: Colors.teal),
                                                        label: const Text('Submit Another', style: TextStyle(color: Colors.teal)),
                                                      ),
                                                    ),
                                                  ),
                                                ],

                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ),
                                ),

                            ],
                          ),
                        ],
                      ),
                ),
              ),




              ),
            ],
          ),
    );
  }
}


class MissionWithStatus {
  final MissionModel mission;
  bool isCompleted;

  MissionWithStatus({
    required this.mission,
    this.isCompleted = false,
  });
}
