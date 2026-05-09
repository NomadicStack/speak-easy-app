document.addEventListener('DOMContentLoaded', () => {
    const inputField = document.getElementById('shorthand-input');
    const clearBtn = document.getElementById('clear-btn');
    const expandBtn = document.getElementById('expand-btn');
    const loadingState = document.getElementById('loading-state');
    const optionsContainer = document.getElementById('options-container');
    const chips = document.querySelectorAll('.chip');
    const toast = document.getElementById('toast');
    const toastMsg = document.getElementById('toast-msg');

    // Simulated AI Responses DB
    const aiResponses = {
        'bus stuck late work': [
            "I'm going to be late for work because my bus is stuck in traffic.",
            "My bus is stuck right now, so I will be running late for work.",
            "I'll be late today. The bus got stuck."
        ],
        'thirsty want water': [
            "I am very thirsty. Could I please have a glass of water?",
            "Can I get some water, please? I'm feeling thirsty.",
            "I would like something to drink. Water, please."
        ],
        'doc appt tomorrow 9': [
            "I have a doctor's appointment tomorrow morning at 9 AM.",
            "My doctor's appointment is scheduled for 9 o'clock tomorrow.",
            "Just a reminder, I need to be at the doctor's tomorrow at 9."
        ],
        'hungry order pizza': [
            "I'm feeling hungry. Should we order a pizza?",
            "Let's order some pizza. I'm really hungry.",
            "I am hungry. I would love to order pizza for dinner."
        ],
        'hungry order pizza pepperoni': [
            "I'm craving pizza. Let's order a pepperoni one.",
            "Can we get a pepperoni pizza? I'm really hungry.",
            "I'm hungry enough for a whole pepperoni pizza right now."
        ],
        'default': [
            "Could you please clarify what you mean?",
            "I need a little more context to say that properly.",
            "I'm trying to say something, but I need a moment."
        ]
    };

    // Handle clear button
    clearBtn.addEventListener('click', () => {
        inputField.value = '';
        inputField.focus();
    });

    // Handle quick chips
    chips.forEach(chip => {
        chip.addEventListener('click', () => {
            inputField.value = chip.dataset.text;
            triggerAIExpansion();
        });
    });

    // Handle expand button
    expandBtn.addEventListener('click', () => {
        if (inputField.value.trim() !== '') {
            triggerAIExpansion();
        }
    });

    // Allow Enter key to trigger expansion
    inputField.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && inputField.value.trim() !== '') {
            triggerAIExpansion();
        }
    });

    // Refinement Logic
    const refinementContainer = document.getElementById('refinement-container');
    const refinementInput = document.getElementById('refinement-input');
    const refineBtn = document.getElementById('refine-btn');

    refineBtn.addEventListener('click', () => {
        if (refinementInput.value.trim() !== '') {
            // Append context to original input
            inputField.value = inputField.value + " " + refinementInput.value.trim();
            refinementInput.value = ''; // clear it
            triggerAIExpansion();
        }
    });

    refinementInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && refinementInput.value.trim() !== '') {
            refineBtn.click();
        }
    });

    function triggerAIExpansion() {
        const text = inputField.value.trim().toLowerCase();
        
        // Hide options & refinement, show loading
        optionsContainer.classList.add('hidden');
        if (refinementContainer) refinementContainer.classList.add('hidden');
        loadingState.classList.remove('hidden');

        // Simulate processing delay (Gemma inference)
        setTimeout(() => {
            loadingState.classList.add('hidden');
            renderOptions(text);
        }, 1500 + Math.random() * 1000); // 1.5 to 2.5 seconds
    }

    function renderOptions(inputText) {
        optionsContainer.innerHTML = '';
        
        // Find matching responses or use default
        let responses = aiResponses['default'];
        for (const key in aiResponses) {
            if (inputText.includes(key) || key.includes(inputText)) {
                responses = aiResponses[key];
                break;
            }
        }

        // Create cards with animation delay
        responses.forEach((response, index) => {
            const card = document.createElement('div');
            card.className = 'option-card';
            card.style.animation = `fadeInUp 0.4s ease forwards ${index * 0.15}s`;
            card.style.opacity = '0';
            
            card.innerHTML = `
                <div class="option-text">"${response}"</div>
                <div class="option-actions">
                    <button class="action-btn play" onclick="playText('${response.replace(/'/g, "\\'")}')">
                        <i class="fa-solid fa-volume-high"></i> Speak
                    </button>
                    <button class="action-btn" onclick="copyText('${response.replace(/'/g, "\\'")}')">
                        <i class="fa-solid fa-copy"></i> Copy
                    </button>
                    <button class="action-btn" onclick="sendText('${response.replace(/'/g, "\\'")}')">
                        <i class="fa-solid fa-paper-plane"></i> Send
                    </button>
                </div>
            `;
            
            optionsContainer.appendChild(card);
        });
        
        optionsContainer.classList.remove('hidden');
        
        // Show refinement option
        if (refinementContainer) {
            refinementContainer.classList.remove('hidden');
            refinementInput.focus();
        }
    }

    // Global functions for inline onclick handlers
    window.playText = function(text) {
        showToast("Speaking: " + text);
        // If the browser supports speech synthesis, actually play it!
        if ('speechSynthesis' in window) {
            const utterance = new SpeechSynthesisUtterance(text);
            utterance.rate = 0.9; // Slightly slower for clarity
            
            // Wait for voices to load (browsers load them async)
            let voices = window.speechSynthesis.getVoices();
            
            // Try to find a young female voice
            let femaleVoice = voices.find(v => 
                v.name.includes('Zoe') || 
                v.name.includes('Samantha') || 
                v.name.includes('Zira') || 
                v.name.includes('Female') || 
                v.name.includes('Woman')
            );
            
            if (femaleVoice) {
                utterance.voice = femaleVoice;
            }
            
            window.speechSynthesis.speak(utterance);
        }
    };

    window.copyText = function(text) {
        navigator.clipboard.writeText(text).then(() => {
            showToast("Copied to clipboard!");
        });
    };

    window.sendText = function(text) {
        showToast("Opening Messages app...");
    };

    function showToast(message) {
        toastMsg.textContent = message;
        toast.classList.remove('hidden');
        
        setTimeout(() => {
            toast.classList.add('hidden');
        }, 3000);
    }
});

// Add keyframes for fade in animation dynamically
const style = document.createElement('style');
style.innerHTML = `
    @keyframes fadeInUp {
        from { opacity: 0; transform: translateY(20px); }
        to { opacity: 1; transform: translateY(0); }
    }
`;
document.head.appendChild(style);
