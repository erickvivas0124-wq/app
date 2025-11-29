#!/usr/bin/env python
"""
Safe script to delete the last 200 cards from the database.
"""
import os
import sys
import django

# Add the project directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mysecondproject.settings')
django.setup()

from posts.models import Card

def main():
    print("=== SAFE CARD DELETION SCRIPT ===")
    print("This will delete the last 200 cards ordered by ID.")

    # Get the cards to delete
    cards_to_delete = Card.objects.order_by('-id')[:94]
    count = cards_to_delete.count()

    if count == 0:
        print("No cards found to delete.")
        return

    print(f"\nFound {count} cards to delete.")
    print("\nFirst 5 cards that will be deleted:")
    for card in cards_to_delete[:5]:
        print(f"  ID: {card.id}, Name: {card.name}")

    if count > 5:
        print(f"\nLast 5 cards that will be deleted:")
        for card in cards_to_delete[count-5:]:
            print(f"  ID: {card.id}, Name: {card.name}")

    # Ask for confirmation
    print(f"\n⚠️  WARNING: This will permanently delete {count} cards!")
    confirm = input("Type 'DELETE' to confirm deletion: ")

    if confirm.upper() == 'DELETE':
        # Get the IDs of cards to delete (since delete() doesn't work with slicing)
        card_ids = list(cards_to_delete.values_list('id', flat=True))

        # Delete using filter
        deleted_count = Card.objects.filter(id__in=card_ids).delete()[0]
        print(f"\n✅ Successfully deleted {deleted_count} cards.")
    else:
        print("\n❌ Deletion cancelled.")

if __name__ == '__main__':
    main()
