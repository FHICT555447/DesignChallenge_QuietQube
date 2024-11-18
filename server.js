const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/', (req, res) => {
    res.send('API werkt!');
});

app.get('/api/data', (req, res) => {
    const data = { message: 'Hallo vanaf de API!', tijd: new Date() };
    res.json(data);
});

let geluidData = [
    { silence_time: 10, average_decibel: 55, max_decibel: 70, created_at: new Date(), updated_at: new Date() },
    { silence_time: 15, average_decibel: 60, max_decibel: 75, created_at: new Date(), updated_at: new Date() },
    { silence_time: 12, average_decibel: 58, max_decibel: 72, created_at: new Date(), updated_at: new Date() },
    { silence_time: 8, average_decibel: 53, max_decibel: 65, created_at: new Date(), updated_at: new Date() },
    { silence_time: 20, average_decibel: 62, max_decibel: 78, created_at: new Date(), updated_at: new Date() },
    { silence_time: 18, average_decibel: 64, max_decibel: 80, created_at: new Date(), updated_at: new Date() },
    { silence_time: 9, average_decibel: 54, max_decibel: 68, created_at: new Date(), updated_at: new Date() },
    { silence_time: 14, average_decibel: 59, max_decibel: 74, created_at: new Date(), updated_at: new Date() },
    { silence_time: 17, average_decibel: 61, max_decibel: 76, created_at: new Date(), updated_at: new Date() },
    { silence_time: 11, average_decibel: 57, max_decibel: 71, created_at: new Date(), updated_at: new Date() }
];

app.get('/api/geluid', (req, res) => {
    res.json(geluidData.slice(-10));
});

app.post('/api/geluid', (req, res) => {
    const { silence_time, average_decibel, max_decibel } = req.body;
    
    if (silence_time === undefined || average_decibel === undefined || max_decibel === undefined) {
        return res.status(400).json({ error: 'Alle velden (silence_time, average_decibel, max_decibel) zijn vereist.' });
    }

    const newRecord = {
        silence_time,
        average_decibel,
        max_decibel,
        created_at: new Date(),
        updated_at: new Date()
    };

    geluidData.push(newRecord);

res.status(201).json({ message: 'Gegevens succesvol toegevoegd.' });
    });

app.listen(port, () => {
    console.log(`Server draait op http://localhost:${port}`);
    });