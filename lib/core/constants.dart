import 'models/user.dart';

class AppConstants {
  static const List<Map<String, dynamic>> hobbies = [
    {'name': 'Football', 'icon': '⚽', 'color': 0xFFFF6B6B},
    {'name': 'Cricket', 'icon': '🏏', 'color': 0xFF4ECDC4},
    {'name': 'Guitar', 'icon': '🎸', 'color': 0xFFFFD93D},
    {'name': 'Singing', 'icon': '🎤', 'color': 0xFF6C63FF},
    {'name': 'Writing', 'icon': '✍️', 'color': 0xFF95A5A6},
    {'name': 'Reading', 'icon': '📚', 'color': 0xFFA8D8EA},
    {'name': 'Hiking', 'icon': '🥾', 'color': 0xFF2ECC71},
    {'name': 'Photography', 'icon': '📸', 'color': 0xFFE056FD},
    {'name': 'Gaming', 'icon': '🎮', 'color': 0xFF3498DB},
    {'name': 'Cooking', 'icon': '🍳', 'color': 0xFFE67E22},
    {'name': 'Dancing', 'icon': '💃', 'color': 0xFFF1C40F},
    {'name': 'Yoga', 'icon': '🧘', 'color': 0xFF1ABC9C},
    {'name': 'Art', 'icon': '🎨', 'color': 0xFF9B59B6},
    {'name': 'Travel', 'icon': '✈️', 'color': 0xFF34495E},
    {'name': 'Music', 'icon': '🎵', 'color': 0xFFE74C3C},
    {'name': 'Coding', 'icon': '💻', 'color': 0xFF2C3E50},
  ];

  static final List<User> dummyUsers = [
    User(
      id: '1',
      name: 'Sarah Mitchell',
      bio:
          'Adventure seeker and nature lover. Always looking for the next mountain to climb! 🏔️',
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1551632811-561732d1e306?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Hiking', 'Photography', 'Travel', 'Yoga'],
      location: 'Seattle, WA',
      age: 28,
    ),
    User(
      id: '2',
      name: 'Alex Chen',
      bio: 'Full-stack developer by day, gamer by night. Coffee enthusiast ☕',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Coding', 'Gaming', 'Coffee', 'Music'],
      location: 'San Francisco, CA',
      age: 26,
    ),
    User(
      id: '3',
      name: 'Maya Patel',
      bio:
          'Creating art, one brushstroke at a time. Yoga instructor and mindfulness advocate.',
      avatarUrl:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1513364776144-60967b0f800f?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Art', 'Yoga', 'Cooking', 'Reading'],
      location: 'Austin, TX',
      age: 31,
    ),
    User(
      id: '4',
      name: 'Jake Thompson',
      bio:
          'Sports fanatic! Live for the game. Cricket and football are life! ⚽🏏',
      avatarUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Football', 'Cricket', 'Hiking', 'Gaming'],
      location: 'London, UK',
      age: 24,
    ),
    User(
      id: '5',
      name: 'Olivia Martinez',
      bio:
          'Singer-songwriter with a passion for guitar. Music is my language 🎵',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1511379938547-c1f69419868d?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Singing', 'Guitar', 'Music', 'Writing'],
      location: 'Nashville, TN',
      age: 27,
    ),
    User(
      id: '6',
      name: 'Ethan Brooks',
      bio:
          'Capturing moments through my lens. Travel photographer exploring the world.',
      avatarUrl:
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1542038784424-fa00ea147159?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Photography', 'Travel', 'Hiking', 'Art'],
      location: 'New York, NY',
      age: 29,
    ),
    User(
      id: '7',
      name: 'Zara Johnson',
      bio:
          'Dance like nobody\'s watching! Professional dancer and choreographer 💃',
      avatarUrl:
          'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1504609773096-104ff2c73ba4?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Dancing', 'Music', 'Yoga', 'Travel'],
      location: 'Miami, FL',
      age: 25,
    ),
    User(
      id: '8',
      name: 'Liam O\'Brien',
      bio:
          'Book lover and aspiring novelist. Coffee, cats, and good stories ☕📖',
      avatarUrl:
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Reading', 'Writing', 'Cooking', 'Art'],
      location: 'Dublin, Ireland',
      age: 30,
    ),
    User(
      id: '9',
      name: 'Priya Sharma',
      bio:
          'Chef passionate about fusion cuisine. Experimenting with flavors from around the world!',
      avatarUrl:
          'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1466637574441-749b8f19452f?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Cooking', 'Travel', 'Photography', 'Reading'],
      location: 'Mumbai, India',
      age: 32,
    ),
    User(
      id: '10',
      name: 'Marcus Williams',
      bio: 'Competitive gamer and streamer. Always up for a challenge! 🎮',
      avatarUrl:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Gaming', 'Coding', 'Music', 'Football'],
      location: 'Los Angeles, CA',
      age: 23,
    ),
    User(
      id: '11',
      name: 'Emma Taylor',
      bio:
          'Yoga teacher finding balance. Mindfulness, meditation, and mountain air 🧘‍♀️',
      avatarUrl:
          'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1544367563-121910aa662f?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Yoga', 'Hiking', 'Reading', 'Cooking'],
      location: 'Denver, CO',
      age: 28,
    ),
    User(
      id: '12',
      name: 'Noah Anderson',
      bio:
          'Indie musician and guitar enthusiast. Making music that speaks to the soul.',
      avatarUrl:
          'https://images.unsplash.com/photo-1504257432389-52343af06ae3?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Guitar', 'Music', 'Singing', 'Art'],
      location: 'Portland, OR',
      age: 26,
    ),
    User(
      id: '13',
      name: 'Ava Robinson',
      bio:
          'Digital nomad exploring the world. Travel blogger and adventure junkie! ✈️',
      avatarUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Travel', 'Writing', 'Photography', 'Hiking'],
      location: 'Bali, Indonesia',
      age: 29,
    ),
    User(
      id: '14',
      name: 'Ryan Foster',
      bio:
          'Cricket coach and sports analyst. Living and breathing the game! 🏏',
      avatarUrl:
          'https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1531415074968-036ba1b575da?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Cricket', 'Football', 'Yoga', 'Cooking'],
      location: 'Melbourne, Australia',
      age: 34,
    ),
    User(
      id: '15',
      name: 'Sophia Kim',
      bio:
          'Tech entrepreneur and coder. Building the future, one line at a time 💻',
      avatarUrl:
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=300&h=300&fit=crop',
      backgroundImageUrl:
          'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?q=80&w=1000&auto=format&fit=crop',
      hobbies: ['Coding', 'Reading', 'Gaming', 'Travel'],
      location: 'Seoul, South Korea',
      age: 27,
    ),
  ];
}
