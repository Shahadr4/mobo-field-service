import 'package:flutter/material.dart';

Widget actionButton({
  required String label,
  required List<List<dynamic>> icon,
  required VoidCallback onPressed,

}){
  return InkWell(
    onTap: onPressed,

    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],

      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add,color: Colors.white,),
          SizedBox(width: 10,),
          Text(label,style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white
          ),),
        ],
      ),

    ),
  );
}
