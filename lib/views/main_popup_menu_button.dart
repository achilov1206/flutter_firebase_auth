import 'package:fbauth/bloc/app_bloc.dart';
import 'package:fbauth/bloc/app_event.dart';
import 'package:fbauth/dialogs/delete_account_dialog.dart';
import 'package:fbauth/dialogs/logout_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum MenuActions { logout, deleteAccount }

class MainPopupMenuButton extends StatelessWidget {
  const MainPopupMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MenuActions>(
      onSelected: (value) async {
        switch (value) {
          case MenuActions.logout:
            final shouldLogOut = await showLogOutDialog(context);
            if (shouldLogOut) {
              context.read<AppBloc>().add(const AppEventLogOut());
            }
            break;
          case MenuActions.deleteAccount:
            final shouldDeleteAccount = await showDeleteAccountDialog(context);
            if (shouldDeleteAccount) {
              context.read<AppBloc>().add(const AppEventDeleteAccount());
            }
            break;
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem<MenuActions>(
            value: MenuActions.logout,
            child: Text('Log Out'),
          ),
          const PopupMenuItem<MenuActions>(
            value: MenuActions.deleteAccount,
            child: Text('Delete account'),
          ),
        ];
      },
    );
  }
}
