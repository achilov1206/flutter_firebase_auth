import 'dart:io';

import 'package:fbauth/auth/auth_error.dart';
import 'package:fbauth/bloc/app_event.dart';
import 'package:fbauth/bloc/app_state.dart';
import 'package:fbauth/utils/upload_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc()
      : super(const AppStateLoggedOut(
          isLoading: false,
        )) {
    // go to registration view
    on<AppEventGoToRegistration>(
      (event, emit) {
        emit(
          const AppStateInRegistrationView(
            isLoading: false,
          ),
        );
      },
    );

    // login
    on<AppEventLogIn>(
      (event, emit) async {
        emit(
          const AppStateLoggedOut(
            isLoading: true,
          ),
        );
        //log the user in
        try {
          final email = event.email;
          final password = event.password;
          final userCredential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          //get images for user
          final user = userCredential.user!;
          final images = await _getImages(user.uid);
          emit(
            AppStateLoggedIn(
              isLoading: false,
              user: user,
              images: images,
            ),
          );
        } on FirebaseAuthException catch (e) {
          emit(
            AppStateLoggedOut(
              isLoading: false,
              authError: AuthError.from(e),
            ),
          );
        }
      },
    );

    on<AppEventGoToLogin>(
      (event, emit) {
        emit(
          const AppStateLoggedOut(
            isLoading: false,
          ),
        );
      },
    );

    //register user
    on<AppEventRegister>(
      (event, emit) async {
        emit(
          const AppStateInRegistrationView(
            isLoading: true,
          ),
        );
        final email = event.email;
        final password = event.password;
        try {
          //create the user
          final credentials =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          emit(
            AppStateLoggedIn(
              isLoading: false,
              user: credentials.user!,
              images: const [],
            ),
          );
        } on FirebaseAuthException catch (e) {
          emit(
            AppStateInRegistrationView(
              isLoading: false,
              authError: AuthError.from(e),
            ),
          );
        }
      },
    );

    //app initizalize
    on<AppEventInitialize>(
      (event, emit) async {
        //get the current user
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          emit(
            const AppStateLoggedOut(
              isLoading: false,
            ),
          );
        } else {
          //get user uploaded images
          final images = await _getImages(user.uid);
          emit(
            AppStateLoggedIn(
              isLoading: false,
              user: user,
              images: images,
            ),
          );
        }
      },
    );

    //handle log out
    on<AppEventLogOut>(
      (event, emit) async {
        emit(
          const AppStateLoggedOut(
            isLoading: true,
          ),
        );
        //log the user out
        await FirebaseAuth.instance.signOut();
        emit(
          const AppStateLoggedOut(
            isLoading: false,
          ),
        );
      },
    );

    //account deletion
    on<AppEventDeleteAccount>(
      (event, emit) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          emit(
            const AppStateLoggedOut(
              isLoading: false,
            ),
          );
          return;
        }
        //start the loading process
        emit(
          AppStateLoggedIn(
            isLoading: true,
            user: user,
            images: state.images ?? [],
          ),
        );
        //delete the user folder
        try {
          //delete user folder
          final folderContent =
              await FirebaseStorage.instance.ref(user.uid).listAll();
          //delete files in folder
          for (final item in folderContent.items) {
            await item.delete().catchError((_) {});
          }
          //delete the folder itself
          await FirebaseStorage.instance
              .ref(user.uid)
              .delete()
              .catchError((_) {});
          //delete the user
          await user.delete();
          //log the user out
          await FirebaseAuth.instance.signOut();
          emit(
            const AppStateLoggedOut(
              isLoading: false,
            ),
          );
        } on FirebaseAuthException catch (e) {
          emit(
            AppStateLoggedIn(
              isLoading: false,
              user: user,
              images: state.images ?? [],
              authError: AuthError.from(e),
            ),
          );
        } on FirebaseException {
          //can not delete folder, log the user out
          emit(
            const AppStateLoggedOut(
              isLoading: false,
            ),
          );
        }
      },
    );

    //uploading image
    on<AppEventUploadImage>(
      (event, emit) async {
        final user = state.user;
        if (user == null) {
          emit(
            const AppStateLoggedOut(
              isLoading: false,
            ),
          );
          return;
        }
        //start the loading process
        emit(
          AppStateLoggedIn(
            isLoading: true,
            user: user,
            images: state.images ?? [],
          ),
        );
        final file = File(event.filePathToUpload);
        await uploadImage(
          file: file,
          userId: user.uid,
        );
        // after upload  is complete grab the latest file reference
        final images = await _getImages(user.uid);
        //emit new images and turn off loading
        emit(AppStateLoggedIn(
          isLoading: false,
          user: user,
          images: images,
        ));
      },
    );
  }

  Future<Iterable<Reference>> _getImages(String userId) =>
      FirebaseStorage.instance
          .ref(userId)
          .list()
          .then((listResult) => listResult.items);
}
