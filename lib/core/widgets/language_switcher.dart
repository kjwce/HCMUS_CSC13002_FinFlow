import 'package:flutter/material.dart';

import '../i18n/app_language.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// A toggle-switch style language switcher (VI / EN).
class LanguageSwitcherFab extends StatelessWidget {
  const LanguageSwitcherFab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        final isEn = AppLanguage.instance.locale.code == 'en';
        return GestureDetector(
          onTap: () => context.toggleLanguage(),
          child: Container(
            width: Responsive.w(context, 72),
            height: Responsive.h(context, 34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // VI side
                Expanded(
                  child: Container(
                    height: Responsive.h(context, 34),
                    decoration: BoxDecoration(
                      color: !isEn
                          ? AppColors.primaryGreen
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        bottomLeft: Radius.circular(30),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'VI',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.sp(context, 13),
                        color: !isEn ? Colors.white : const Color(0xFF797C7A),
                      ),
                    ),
                  ),
                ),
                // EN side
                Expanded(
                  child: Container(
                    height: Responsive.h(context, 34),
                    decoration: BoxDecoration(
                      color: isEn ? AppColors.primaryGreen : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'EN',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: Responsive.sp(context, 13),
                        color: isEn ? Colors.white : const Color(0xFF797C7A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An icon-button positioned in AppBar actions to toggle language.
class LanguageSwitcherIcon extends StatelessWidget {
  const LanguageSwitcherIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        final isEn = AppLanguage.instance.locale.code == 'en';
        return IconButton(
          onPressed: () => context.toggleLanguage(),
          icon: Text(
            isEn ? 'VN' : 'EN',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.deepEmerald,
              fontSize: Responsive.sp(context, 14),
            ),
          ),
          tooltip: isEn ? 'Tiếng Việt' : 'English',
        );
      },
    );
  }
}
