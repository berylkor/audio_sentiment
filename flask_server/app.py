from flask import Flask, request, jsonify
import librosa
import numpy as np
import tensorflow as tf

app = Flask(__name__)

# Load the sentiment analysis model
model = tf.keras.models.load_model('voice_insights_model.h5')

# Function to extract features from audio
def extract_features(audio_path):
    data, sample_rate = librosa.load(audio_path, duration=2.5, offset=0.6)
    features = np.mean(librosa.feature.mfcc(y=data, sr=sample_rate).T, axis=0)
    return features

@app.route('/analyze', methods=['POST'])
def analyze_audio():
    if 'audio' not in request.files:
        return jsonify({'error': 'No audio file provided'}), 400

    audio_file = request.files['audio']
    audio_path = f"tmp/{audio_file.filename}"
    audio_file.save(audio_path)

    try:
        features = extract_features(audio_path)
        features = np.expand_dims(features, axis=0)
        prediction = model.predict(features)
        emotion_index = np.argmax(prediction, axis=1)[0]
        emotions = ['Angry', 'Happy', 'Neutral', 'Sad']
        emotion = emotions[emotion_index]
        return jsonify({'emotion': emotion})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)