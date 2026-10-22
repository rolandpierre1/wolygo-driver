import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_appbar_widget.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/email_checker.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/signup_body.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/text_field_title_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/text_field_widget.dart';

class AdditionalSignUpScreen2 extends StatelessWidget {

  const AdditionalSignUpScreen2({super.key,});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<AuthController>(builder: (authController){
          return Column(children: [
            SignUpAppbarWidget(title: 'signup_as_a_driver', progressText: '3_of_3',enableBackButton: true),
            
            Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Text('provide_your_identity'.tr,style: textBold.copyWith(color: Theme.of(context).primaryColor,fontSize: 22))),

                        Center(
                          child: Text('this_information_will_help'.tr, style: textRegular.copyWith(
                            color: Theme.of(context).primaryColor.withOpacity(0.5),fontSize: Dimensions.fontSizeSmall,
                          )),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeLarge),
        
                        TextFieldTitleWidget(title: '${'identity_type'.tr}*'),
        
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(width: .5, color: Theme.of(context).hintColor.withOpacity(.7)),
                          ),
                          child: DropdownButton<String>(
                            hint: authController.identityType == '' ?
                            Text('select_identity_type'.tr,style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium!.color)) :
                            Text(
                              authController.identityType.tr,
                              style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium!.color),
                            ),
                            items: authController.identityTypeList.map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value.tr,style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium!.color)));
                            }).toList(),
                            onChanged: (val) {
                              authController.setIdentityType(val!);
                            },
                            isExpanded: true,
                            underline: const SizedBox(),
                          ),
                        ),
        
                        TextFieldTitleWidget(title: '${'identification_number'.tr}*'),
        
                        TextFieldWidget(
                          hintText: 'Ex: 12345',
                          inputType: TextInputType.text,
                          prefixIcon: Images.identity,
                          controller: authController.identityNumberController,
                          focusNode: authController.identityNumberNode,
                          inputAction: TextInputAction.done,
                        ),
        
                        TextFieldTitleWidget(title: '${'identity_image'.tr}*'),
        
                        Padding(
                          padding:  const EdgeInsets.fromLTRB(
                            Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault,
                            Dimensions.paddingSizeDefault,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount : authController.identityImages.length >= 2 ?
                            2:
                            authController.identityImages.length + 1,
                            itemBuilder: (BuildContext context, index){
                              return index ==  authController.identityImages.length ?
                              GestureDetector(
                                onTap: ()=> authController.pickImage(false, false),
                                child: DottedBorder(
                                  strokeWidth: 2,
                                  dashPattern: const [10,5],
                                  color: Theme.of(context).hintColor,
                                  borderType: BorderType.RRect,
                                  radius: const Radius.circular(Dimensions.paddingSizeSmall),
                                  child: Stack(children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                                      child:  SizedBox(
                                        height: MediaQuery.of(context).size.width/4.3,
                                        width: MediaQuery.of(context).size.width,
                                        child: Image.asset(Images.cameraPlaceholder, scale: 3),
                                      ),
                                    ),
        
                                    Positioned(
                                      bottom: 0, right: 0, top: 0, left: 0,
                                      child: Container(decoration: BoxDecoration(
                                        color: Theme.of(context).hintColor.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                                      )),
                                    ),
                                  ]),
                                ),
                              ) :
                              Stack(children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.all(Radius.circular(20)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(Dimensions.paddingSizeExtraSmall),
                                      ),
                                      child:  Image.file(
                                        File(authController.identityImages[index].path),
                                        width: MediaQuery.of(context).size.width,
                                        height: MediaQuery.of(context).size.width/4.3,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
        
                                Positioned(
                                  top:0,right:0,
                                  child: InkWell(
                                    onTap :() => authController.removeImage(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.all(Radius.circular(
                                          Dimensions.paddingSizeDefault,
                                        )),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.delete_forever_rounded,color: Colors.red,size: 15),
                                      ),
                                    ),
                                  ),
                                ),
                              ]);
        
                            },
                          ),
                        ),
        
                        TextFieldTitleWidget(title: (Get.locale?.languageCode ?? 'fr') == 'fr'
                            ? 'Documents du véhicule (permis, immatriculation, assurance)'
                            : 'Vehicle documents (licence, registration, insurance)'),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (int i = 0; i < authController.vehicleDocImages.length; i++)
                              Stack(children: [
                                ClipRRect(borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(authController.vehicleDocImages[i].path), width: 80, height: 80, fit: BoxFit.cover)),
                                Positioned(top: 0, right: 0, child: InkWell(
                                  onTap: () => authController.removeVehicleDoc(i),
                                  child: Container(color: Colors.white,
                                    child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18)))),
                              ]),
                            InkWell(
                              onTap: () => authController.pickVehicleDoc(),
                              child: Container(width: 80, height: 80,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Theme.of(context).hintColor)),
                                child: Icon(Icons.add_a_photo_outlined, color: Theme.of(context).hintColor)),
                            ),
                          ]),
                        ),

                        authController.isLoading ?
                        Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0)) :
                        ButtonWidget(buttonText: 'submit'.tr,
                            onPressed: () async {
                              String email = authController.emailController.text.trim();
                              String address = authController.addressController.text.trim();
                              String identityNumber = authController.identityNumberController.text;
                              if(identityNumber.isEmpty){
                                showCustomSnackBar('identity_number_is_required'.tr);
                                FocusScope.of(context).requestFocus(authController.identityNumberNode);
                              }else if(authController.identityImages.isEmpty){
                                showCustomSnackBar('identity_image_is_required'.tr);
                              }else if(authController.identityType.isEmpty){
                                showCustomSnackBar('identity_type_is_required'.tr);
                              }
                              else{
                                List<String> services = [];
                                if(authController.isRideShare){
                                  services.add('ride_request');
                                }
                                if(authController.isParcelShare){
                                  services.add('parcel');
                                }
                                String? deviceToken;
                                try {
                                  deviceToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
                                } catch (_) {
                                  deviceToken = null;
                                }
                                SignUpBody signUpBody = SignUpBody(
                                    email: email,
                                    address: address,
                                    identityNumber: identityNumber,
                                    identificationType: authController.identityType,
                                    fName: authController.fNameController.text,
                                    lName: authController.lNameController.text,
                                    phone: authController.countryDialCode+authController.phoneController.text,
                                    password: authController.passwordController.text,
                                    confirmPassword: authController.confirmPasswordController.text,
                                    deviceToken: authController.getDeviceToken(),
                                    services: services,
                                    referralCode: authController.referralCodeController.text.trim(),
                                    fcmToken: deviceToken,
                                    extra: {
                                      'vehicle_brand_id': authController.signupBrand?.id ?? '',
                                      'vehicle_model_id': authController.signupModel?.id ?? '',
                                      'vehicle_category_id': authController.signupCategory?.id ?? '',
                                      'vehicle_plate': authController.vehiclePlateController.text.trim(),
                                      'vehicle_licence_expire_date': authController.vehicleExpireController.text,
                                      'vehicle_fuel_type': authController.signupFuel,
                                    },
                                );
                                authController.register(authController.countryDialCode, signUpBody);
                              }
                            }, radius: 50),
        
                        const SizedBox(height: Dimensions.paddingSizeDefault,),
                      ],
                    ),
                  ),
                )
            )
          ]);
        }),
      ),
    );
  }
}
