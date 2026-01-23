const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    appleId: {
        type: String,
        required: true,
        unique: true,
        index: true,
    },
    email: {
        type: String,
        lowercase: true,
    },
    firstName: String,
    lastName: String,
    profilePicture: String,
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);
