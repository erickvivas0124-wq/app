from rest_framework import serializers, viewsets
from django import forms
from .models import Card

class CardForm(forms.ModelForm):
    class Meta:
        model = Card
        fields = ['name', 'image', 'brand', 'model', 'series', 'risk', 'location', 'status']


