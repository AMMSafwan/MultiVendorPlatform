import {
  StatusBar,
  StyleSheet,
  Text,
  View
} from 'react-native';

export default function App() {
  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" />

      <Text style={styles.label}>
        MULTI-VENDOR MARKETPLACE
      </Text>

      <Text style={styles.title}>
        Welcome to Your Marketplace
      </Text>

      <Text style={styles.subtitle}>
        Shop products, book local services
        and track deliveries in Sri Lanka.
      </Text>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>
          Development progress
        </Text>

        <Text style={styles.item}>
          ✓ Mobile application created
        </Text>

        <Text style={styles.item}>
          ✓ Express backend created
        </Text>

        <Text style={styles.item}>
          ○ Supabase database — next lesson
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F7FB',
    justifyContent: 'center',
    padding: 24
  },

  label: {
    color: '#5265D8',
    fontSize: 12,
    fontWeight: 'bold',
    marginBottom: 12
  },

  title: {
    fontSize: 27,
    fontWeight: 'bold',
    color: '#172033',
    marginBottom: 12
  },

  subtitle: {
    fontSize: 15,
    color: '#667085',
    lineHeight: 23
  },

  card: {
    backgroundColor: '#FFFFFF',
    padding: 20,
    borderRadius: 14,
    marginTop: 30
  },

  cardTitle: {
    fontSize: 17,
    fontWeight: 'bold',
    marginBottom: 15
  },

  item: {
    fontSize: 14,
    color: '#344054',
    marginBottom: 12
  }
});