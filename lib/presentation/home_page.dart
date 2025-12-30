import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:adhan/adhan.dart';
import 'package:prayer_times_app/data/services/notification_service.dart';
import 'package:prayer_times_app/presentation/qubla_finder.dart';
import 'package:prayer_times_app/presentation/viewmodels/prayer_viewmodel.dart';
import 'package:prayer_times_app/presentation/settings/app_settings_page.dart';
import 'package:prayer_times_app/presentation/hisn_page.dart';
import 'package:prayer_times_app/presentation/widgets/prayer_banner_ad.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static DateTime? _lastInterstitialShown;

  void _showInterstitialAndNavigate(BuildContext context, Widget page) {
    final now = DateTime.now();

    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < const Duration(seconds: 30)) {
      debugPrint('⏱️ Interstitial cooldown active, navigating without ad');
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      return;
    }

    _lastInterstitialShown = now;

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3322345933938430/4543357572',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('✅ Interstitial loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (Ad adObj) {
              adObj.dispose();
              debugPrint('✅ Interstitial dismissed');
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            },
            onAdFailedToShowFullScreenContent: (Ad adObj, AdError error) {
              adObj.dispose();
              debugPrint('❌ Failed to show interstitial: $error');
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            },
          );

          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Failed to load interstitial: $error');

          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prayerViewModelProvider);
    final viewModel = ref.read(prayerViewModelProvider.notifier);
    final notificationService = ref.read(notificationServiceProvider);

    final timerStyle = GoogleFonts.robotoMono(
      fontSize: 46.sp,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    final prayerTimeStyle = GoogleFonts.robotoMono(
      fontSize: 19.sp,
      fontWeight: FontWeight.bold,
      color: Colors.tealAccent,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 100.w,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w, top: 6.h),
          child: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/settings.svg',
              width: 28.w,
              height: 28.h,
              colorFilter: ColorFilter.mode(
                Colors.white.withAlpha(200),
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AppSettingsPage(
                    onSettingsChanged: viewModel.refreshNotifications,
                    notificationsPlugin:
                        notificationService.flutterLocalNotificationsPlugin,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: BoxDecoration(gradient: viewModel.getDynamicGradient()),
          ),
          Opacity(
            opacity: 0.04,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/back.png'),
                  repeat: ImageRepeat.repeat,
                  alignment: Alignment(0.0, 0.7),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 16.h),
                          Center(
                            child: PrayerBannerAd(
                              adUnitId:
                                  'ca-app-pub-3322345933938430/6573012749',
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            state.city,
                            style: GoogleFonts.tajawal(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            state.hijriDate,
                            style: GoogleFonts.tajawal(
                              fontSize: 16.sp,
                              color: Colors.white.withAlpha(180),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          SizedBox(height: 25.h),
                          Text(
                            '${state.nextPrayerName} بعد:',
                            style: GoogleFonts.tajawal(
                              fontSize: 20.sp,
                              color: Colors.tealAccent[100],
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            viewModel.formatDuration(
                              state.timeUntilNextPrayer,
                            ),
                            style: timerStyle,
                          ),
                          SizedBox(height: 30.h),
                          if (state.prayerTimes != null) ...[
                            _buildPrayerRow(
                              context,
                              'الفجر',
                              viewModel.formatTime(state.prayerTimes?.fajr),
                              'fajr.svg',
                              state.nextPrayer == Prayer.fajr,
                              prayerTimeStyle,
                            ),
                            _buildPrayerRow(
                              context,
                              'الشروق',
                              viewModel.formatTime(
                                state.prayerTimes?.sunrise,
                              ),
                              'sunrise.svg',
                              state.nextPrayer == Prayer.sunrise,
                              prayerTimeStyle,
                            ),
                            _buildPrayerRow(
                              context,
                              'الظهر',
                              viewModel.formatTime(state.prayerTimes?.dhuhr),
                              'dhuhr.svg',
                              state.nextPrayer == Prayer.dhuhr,
                              prayerTimeStyle,
                            ),
                            _buildPrayerRow(
                              context,
                              'العصر',
                              viewModel.formatTime(state.prayerTimes?.asr),
                              'asr.svg',
                              state.nextPrayer == Prayer.asr,
                              prayerTimeStyle,
                            ),
                            _buildPrayerRow(
                              context,
                              'المغرب',
                              viewModel.formatTime(
                                state.prayerTimes?.maghrib,
                              ),
                              'maghrib.svg',
                              state.nextPrayer == Prayer.maghrib,
                              prayerTimeStyle,
                            ),
                            _buildPrayerRow(
                              context,
                              'العشاء',
                              viewModel.formatTime(state.prayerTimes?.isha),
                              'isha.svg',
                              state.nextPrayer == Prayer.isha,
                              prayerTimeStyle,
                            ),
                          ],
                          SizedBox(height: 20.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMainButton(
                                context,
                                iconPath: 'assets/icons/book.svg',
                                label: 'حصن المسلم',
                                onTap: () => _showInterstitialAndNavigate(
                                  context,
                                  const HisnPage(),
                                ),
                              ),
                              _buildMainButton(
                                context,
                                iconPath: 'assets/icons/qubla.svg',
                                label: 'إتجاه القبلة',
                                onTap: () => _showInterstitialAndNavigate(
                                  context,
                                  const QiblaFinder(),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: SizedBox(
          height: 58.h,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.withOpacity(0.12),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
                side: BorderSide(color: Colors.tealAccent.withOpacity(0.45)),
              ),
              elevation: 3,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.ltr,
                children: [
                  SvgPicture.asset(
                    iconPath,
                    width: 26.w,
                    height: 26.h,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    label,
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerRow(
    BuildContext context,
    String name,
    String time,
    String iconName,
    bool isNextPrayer,
    TextStyle timeStyle,
  ) {
    final containerColor = isNextPrayer
        ? const Color(0xFF1E1E1E).withOpacity(0.7)
        : const Color(0xFF1E1E1E).withOpacity(0.9);

    final borderColor =
        isNextPrayer ? Colors.tealAccent.withOpacity(0.7) : Colors.transparent;

    final iconColor =
        isNextPrayer ? Colors.tealAccent : Colors.white.withAlpha(200);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isNextPrayer
            ? [
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.15),
                  blurRadius: 10.r,
                  spreadRadius: 1.r,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/$iconName',
            width: 24.w,
            height: 24.h,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
          SizedBox(width: 16.w),
          Text(
            name,
            style: GoogleFonts.tajawal(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: isNextPrayer ? Colors.white : Colors.white.withAlpha(200),
            ),
          ),
          const Spacer(),
          Text(time, style: timeStyle),
        ],
      ),
    );
  }
}
