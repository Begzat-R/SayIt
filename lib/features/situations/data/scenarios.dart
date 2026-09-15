import '../models/scenario.dart';

const List<Scenario> kScenarios = [
  Scenario(
    id: 'order_food',
    title: 'Ordering food',
    context: 'At a counter or table. Someone\'s waiting for your order.',
    iconName: 'coffee',
    category: 'Everyday',
  ),
  Scenario(
    id: 'phone_call',
    title: 'Phone call',
    context: 'Dialing in. The line picks up.',
    iconName: 'phone',
    category: 'Everyday',
    simulatedPrompt:
        'Thank you for calling. For billing, press 1. For technical support, press 2. '
        'To speak with a representative, press 0 or say "representative." [pause] '
        'I\'m sorry, I didn\'t catch that. Please say your selection or press a key.',
  ),
  Scenario(
    id: 'say_name',
    title: 'Saying your name',
    context: 'Someone just asked. It\'s your turn.',
    iconName: 'user',
    category: 'Social',
  ),
  Scenario(
    id: 'job_interview',
    title: 'Job interview opener',
    context: '"Tell me about yourself." They\'re looking at you.',
    iconName: 'briefcase',
    category: 'Work',
  ),
  Scenario(
    id: 'small_talk',
    title: 'Small talk',
    context: 'Elevator, waiting room, first day somewhere new.',
    iconName: 'chat',
    category: 'Social',
  ),
  Scenario(
    id: 'ask_directions',
    title: 'Asking for directions',
    context: 'You\'re turned around. There\'s someone nearby who looks approachable.',
    iconName: 'map_pin',
    category: 'Social',
  ),
];
