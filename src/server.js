const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const { SpeechConfig, AudioConfig, SpeechRecognizer } = require('microsoft-cognitiveservices-speech-sdk');
const axios = require('axios');

const app = express();
const db = new sqlite3.Database('./wishes.db');

// Middleware
app.use(bodyParser.json({ limit: '10mb' }));

// Serve static files from the src directory
app.use(express.static('src'));

// Azure Cognitive Services Configuration
const speechConfig = SpeechConfig.fromSubscription('TREE_SPEECH_KEY', 'TREE_REGION'); // Replace with your Speech Service key and region
const contentSafetyEndpoint = 'https://TREE_CONTENT_SAFETY_ENDPOINT'; // Replace with your Content Safety endpoint
const contentSafetyKey = 'TREE_CONTENT_SAFETY_KEY'; // Replace with your Content Safety key

async function transcribeAudio(audioBuffer) {
    return new Promise((resolve, reject) => {
        const audioConfig = AudioConfig.fromWavFileInput(audioBuffer);
        const recognizer = new SpeechRecognizer(speechConfig, audioConfig);

        recognizer.recognizeOnceAsync(result => {
            if (result.reason === 3) { // RecognizedSpeech
                resolve(result.text);
            } else {
                reject('Speech recognition failed');
            }
        });
    });
}

async function validateContent(text) {
    try {
        const response = await axios.post(
            `${contentSafetyEndpoint}/contentmoderator/moderate/v1.0/ProcessText`,
            { Text: text },
            {
                headers: {
                    'Ocp-Apim-Subscription-Key': contentSafetyKey,
                    'Content-Type': 'application/json'
                }
            }
        );
        return response.data;
    } catch (error) {
        console.error('Content validation failed:', error);
        throw new Error('Content validation failed');
    }
}

// Middleware to get user info from Easy Auth headers
function getUserFromEasyAuth(req) {
    if (req.headers['x-ms-client-principal']) {
        const encoded = req.headers['x-ms-client-principal'];
        const buff = Buffer.from(encoded, 'base64');
        try {
            return JSON.parse(buff.toString('utf8'));
        } catch (e) {
            return null;
        }
    }
    return null;
}

// Middleware to require authentication via Easy Auth
function ensureAuthenticated(req, res, next) {
    const user = getUserFromEasyAuth(req);
    if (user && user.userDetails) {
        req.user = user;
        return next();
    }
    // Not authenticated, redirect to login
    res.redirect('/.auth/login/aad');
}

// Initialize database
const initDb = () => {
    db.run(`CREATE TABLE IF NOT EXISTS wishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        icon TEXT NOT NULL,
        text TEXT NOT NULL,
        author TEXT,
        audioData BLOB
    )`);
};

initDb();

// Updated Endpoint to save a wish (public or protected as needed)
app.post('/save-wish', ensureAuthenticated, async (req, res) => {
    const { icon, text, author, audioData } = req.body;
    if (!text || !icon) {
        return res.status(400).send('Icon and text are required');
    }

    let audioBuffer = null;
    if (audioData) {
        try {
            audioBuffer = Buffer.from(audioData, 'base64');
            const transcribedText = await transcribeAudio(audioBuffer);
            const validationResult = await validateContent(transcribedText);

            if (validationResult.Terms && validationResult.Terms.length > 0) {
                return res.status(400).send('Audio contains inappropriate content');
            }
        } catch (error) {
            console.error('Audio processing failed:', error);
            return res.status(500).send('Failed to process audio');
        }
    }

    db.run('INSERT INTO wishes (icon, text, author, audioData) VALUES (?, ?, ?, ?)', [icon, text, author || 'Anonymous', audioBuffer], function(err) {
        if (err) {
            console.error(err);
            return res.status(500).send('Failed to save wish');
        }
        res.status(200).send({ id: this.lastID });
    });
});

// Endpoint to retrieve all wishes (public or protected as needed)
app.get('/wishes', ensureAuthenticated, (req, res) => {
    db.all('SELECT * FROM wishes', [], (err, rows) => {
        if (err) {
            console.error(err);
            return res.status(500).send('Failed to retrieve wishes');
        }
        const processedRows = rows.map(row => {
            if (row.audioData) {
                const audioBase64 = row.audioData.toString('base64');
                console.log(`Audio length for wish ID ${row.id}: ${audioBase64.length} characters`);
                return { ...row, audioData: audioBase64 };
            }
            return row;
        });
        res.status(200).json(processedRows);
    });
});

// Endpoint to delete a wish (admin only)
app.delete('/delete-wish/:id', ensureAuthenticated, (req, res) => {
    const user = req.user;
    if (!user || !user.userRoles || !user.userRoles.includes('admin')) {
        return res.status(403).send('Access denied');
    }
    const wishId = req.params.id;
    db.run('DELETE FROM wishes WHERE id = ?', [wishId], function(err) {
        if (err) {
            console.error(err);
            return res.status(500).send('Failed to delete wish');
        }
        res.status(200).send('Wish deleted successfully');
    });
});

// Serve the admin page (admin only)
app.get('/admin', ensureAuthenticated, (req, res) => {
    const user = req.user;
    if (user && user.userRoles && user.userRoles.includes('admin')) {
        res.sendFile(__dirname + '/admin.html');
    } else {
        res.status(403).send('Access denied');
    }
});

// Example Protected Route
app.get('/protected', ensureAuthenticated, (req, res) => {
    res.send(`Hello ${req.user.userDetails}, you are authenticated!`);
});

// Endpoint to fetch the user's UPN
app.get('/api/user', ensureAuthenticated, (req, res) => {
    if (req.user && req.user.userDetails) {
        res.json({ upn: req.user.userDetails });
    } else {
        res.status(401).json({ error: 'User not authenticated' });
    }
});

// Start the server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});
