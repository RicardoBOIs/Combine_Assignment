import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/tips_education.dart';


class TipRepository {
  TipRepository._();
  static final TipRepository instance = TipRepository._();


  /* ---------- Local cache ---------- */
  final List<Tip> tips = [];

  /* ---------- Firestore handle ---------- */
  final _tipsCol =
  FirebaseFirestore.instance.collection('EcoLife').doc('tips').collection('items');

  /// Loads tips from Firestore once (call from `main()` or `initState`)
  Future<void> initFromFirestore() async {
    try {
      final snap = await _tipsCol.get();
      if (snap.docs.isNotEmpty) {
        tips
          ..clear()
          ..addAll(snap.docs.map((d) => Tip.fromDoc(d)));
      }
    } catch (e) {

    }
  }

  /// Add a tip: write to Firestore first, then cache & notify
  Future<void> addTip(Tip tip) async {
    try {
      await _tipsCol.doc(tip.title).set((tip.toJson()));

    } finally {

      tips.add(tip);
    }
  }

  Future<bool> deleteTip(String titleId) async {
    try {
      // Delete from Firestore
      await _tipsCol.doc(titleId).delete();



      return true;
    } catch (e) {
      print('Error deleting tip: $e');
      return false;
    }
  }
}

final List<Tip> _seedTips = [
  Tip(
    title: 'Use LED Bulbs',
    subtitle:
    'Switching to LED lighting is one of the most effective ways to reduce energy consumption. LEDs use up to 90% less energy than traditional incandescent bulbs and can last up to 25 times longer, leading to significant cost savings and environmental benefits.',
    reference: 'https://www.energy.gov/energysaver/led-lighting',
  ),
  Tip(
    title: 'Conserve Water',
    subtitle:
    'Fixing household leaks can save approximately 10% on water bills. Simple actions like repairing dripping faucets and running toilets contribute to water conservation and reduce utility expenses.',
    reference: 'https://www.epa.gov/watersense/fix-leak-week',
  ),
  Tip(
    title: 'Recycle Regularly',
    subtitle:
    'Recycling helps reduce the amount of waste sent to landfills and conserves natural resources. It also saves energy and reduces greenhouse gas emissions, contributing to environmental sustainability.',
    reference: 'https://www.epa.gov/recycle/recycling-basics',
  ),
  Tip(
    title: 'Plant Trees',
    subtitle:
    'Trees absorb carbon dioxide, provide oxygen, and help combat climate change. Planting trees in your community can improve air quality, conserve water, and enhance biodiversity.',
    reference: 'https://www.arborday.org/trees/benefits.cfm',
  ),
  Tip(
    title: 'Take Shorter Showers',
    subtitle:
    'Reducing shower time can save significant amounts of water and energy. A typical shower uses about 2.5 gallons of water per minute; cutting back even a few minutes can lead to substantial savings.',
    reference: 'https://www.epa.gov/watersense/showerheads',
  ),
  Tip(
    title: 'Unplug Devices',
    subtitle:
    'Many electronic devices consume energy even when turned off, known as phantom loads. Unplugging devices when not in use can prevent unnecessary energy consumption and lower electricity bills.',
    reference: 'https://www.energy.gov/energysaver/reducing-electricity-use-standby-power',
  ),
  Tip(
    title: 'Use Reusable Bags',
    subtitle:
    'Using reusable bags reduces the need for single-use plastic bags, which are harmful to the environment. Reusable bags are durable, cost-effective, and help decrease plastic pollution.',
    reference: 'https://www.epa.gov/trash-free-waters/what-you-can-do',
  ),
  Tip(
    title: 'Compost Food Waste',
    subtitle:
    'Composting food scraps and yard waste reduces the amount of garbage sent to landfills and lowers methane emissions. Compost enriches soil, helping retain moisture and suppress plant diseases.',
    reference: 'https://www.epa.gov/recycle/composting-home',
  ),
  Tip(
    title: 'Buy Local Produce',
    subtitle:
    'Purchasing locally grown food supports local economies and reduces the carbon footprint associated with transporting goods over long distances. It also ensures fresher produce for consumers.',
    reference: 'https://www.nrdc.org/stories/eat-local',
  ),
  Tip(
    title: 'Support Renewable Energy',
    subtitle:
    'Choosing renewable energy sources like solar or wind power reduces reliance on fossil fuels, decreases greenhouse gas emissions, and promotes a sustainable energy future.',
    reference: 'https://www.energy.gov/eere/renewable-energy',
  ),

];
