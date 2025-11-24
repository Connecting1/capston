// lib/main.dart (전체 라우팅)
import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/knowledge_check_screen.dart';
import 'screens/first_explanation_screen.dart';
import 'screens/first_reflection_screen.dart';
import 'screens/ai_explanation_screen.dart';
import 'screens/second_explanation_screen.dart';
import 'screens/second_reflection_screen.dart';
import 'screens/evaluation_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feynman AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          elevation: 2,
          centerTitle: true,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
      // 라우팅 설정
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;
        
        switch (settings.name) {
          case '/knowledge_check':
            return MaterialPageRoute(
              builder: (context) => KnowledgeCheckScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
              ),
            );
            
          case '/first_explanation':
            return MaterialPageRoute(
              builder: (context) => FirstExplanationScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
              ),
            );
            
          case '/first_reflection':
            return MaterialPageRoute(
              builder: (context) => FirstReflectionScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
                explanation: args['explanation'],
              ),
            );
            
          case '/ai_explanation':
            return MaterialPageRoute(
              builder: (context) => AIExplanationScreen(
                roomId: args!['roomId'],
                concept: args['concept'],
                explanation: args['explanation'],
                reflection: args['reflection'],
              ),
            );
            
          case '/second_explanation':
            return MaterialPageRoute(
              builder: (context) => SecondExplanationScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
                firstExplanation: args['firstExplanation'],
                firstReflection: args['firstReflection'],
              ),
            );
            
          case '/second_reflection':
            return MaterialPageRoute(
              builder: (context) => SecondReflectionScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
                firstExplanation: args['firstExplanation'],
                firstReflection: args['firstReflection'],
                secondExplanation: args['secondExplanation'],
              ),
            );
            
          case '/evaluation':
            return MaterialPageRoute(
              builder: (context) => EvaluationScreen(
                roomId: args!['roomId'],
                concept: args['concept'],
                firstExplanation: args['firstExplanation'],
                firstReflection: args['firstReflection'],
                secondExplanation: args['secondExplanation'],
                secondReflection: args['secondReflection'],
              ),
            );
        }
        
        return null;
      },
    );
  }
}