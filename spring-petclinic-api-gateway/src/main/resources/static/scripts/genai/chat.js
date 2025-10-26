function appendMessage(message, type) {
    const chatMessages = document.getElementById('chatbox-messages');
    const messageElement = document.createElement('div');
    messageElement.classList.add('chat-bubble', type);

    // Convert Markdown to HTML
    const htmlContent = marked.parse(message); // Use marked.parse() for newer versions
    messageElement.innerHTML = htmlContent;

    chatMessages.appendChild(messageElement);

    // Scroll to the bottom of the chatbox to show the latest message
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function toggleChatbox() {
    const chatbox = document.getElementById('chatbox');
    const chatboxContent = document.getElementById('chatbox-content');

    if (chatbox.classList.contains('minimized')) {
        chatbox.classList.remove('minimized');
        chatboxContent.style.height = '400px'; // Set to initial height when expanded
    } else {
        chatbox.classList.add('minimized');
        chatboxContent.style.height = '40px'; // Set to minimized height
    }
}

function sendMessage() {
    const query = document.getElementById('chatbox-input').value;

    // Only send if there's a message
    if (!query.trim()) return;

    // Clear the input field after sending the message
    document.getElementById('chatbox-input').value = '';

    // Display user message in the chatbox
    appendMessage(query, 'user');

    // Send the message to the backend (AWS Lambda GenAI via CloudFront -> API Gateway)
    fetch(window.location.origin + '/api/genai', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ question: query }),  // Lambda 함수에서 'question' 필드를 기대함
    })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.json();  // JSON 응답으로 변경
        })
        .then(data => {
            // Lambda 함수의 응답 구조에 맞게 수정
            const responseText = data.answer || data.message || 'No response received';
            appendMessage(responseText, 'bot');
        })
        .catch(error => {
            console.error('Error:', error);
            // 더 자세한 에러 메시지 표시
            let errorMessage = 'Chat is currently unavailable';
            if (error.message.includes('404')) {
                errorMessage = 'GenAI service not found. Please check the API configuration.';
            } else if (error.message.includes('500')) {
                errorMessage = 'Server error occurred. Please try again later.';
            } else if (error.message.includes('429')) {
                errorMessage = 'Too many requests. Please wait a moment and try again.';
            }
            appendMessage(errorMessage, 'bot');
        });
}

function handleKeyPress(event) {
    if (event.key === "Enter") {
        event.preventDefault(); // Prevents adding a newline
        sendMessage(); // Send the message when Enter is pressed
    }
}

// Save chat messages to localStorage
function saveChatMessages() {
    const messages = document.getElementById('chatbox-messages').innerHTML;
    localStorage.setItem('chatMessages', messages);
}

// Load chat messages from localStorage
function loadChatMessages() {
    const messages = localStorage.getItem('chatMessages');
    if (messages) {
        document.getElementById('chatbox-messages').innerHTML = messages;
        document.getElementById('chatbox-messages').scrollTop = document.getElementById('chatbox-messages').scrollHeight;
    }
}
