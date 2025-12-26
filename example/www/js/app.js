// Access the plugin through Capacitor's Plugins API
const { AppleIntelligence } = Capacitor.Plugins;

// Helper function to display results
function displayResult(result, isError = false) {
    const outputDiv = document.getElementById('output');
    const resultPre = document.getElementById('result');

    outputDiv.style.display = 'block';
    outputDiv.className = isError ? 'output error' : 'output';

    if (isError) {
        resultPre.textContent = `Error: ${result}`;
    } else {
        resultPre.textContent = JSON.stringify(result, null, 2);
    }
}

// Helper function to get input values
function getInputs() {
    return {
        prompt: document.getElementById('prompt').value,
        schema: document.getElementById('schema').value,
        language: document.getElementById('language').value
    };
}

// Helper function to disable/enable buttons
function setButtonsDisabled(disabled) {
    const buttons = document.querySelectorAll('button');
    buttons.forEach(button => button.disabled = disabled);
}

// Test generateJSON method
async function testGenerateJSON() {
    const { prompt, schema } = getInputs();

    if (!prompt || !schema) {
        displayResult('Please enter both a prompt and a schema', true);
        return;
    }

    try {
        setButtonsDisabled(true);
        displayResult('Generating JSON...', false);

        // Parse the schema to validate it
        let parsedSchema;
        try {
            parsedSchema = JSON.parse(schema);
        } catch (e) {
            throw new Error('Invalid JSON schema: ' + e.message);
        }

        const result = await AppleIntelligence.generate({
            messages: [
                { role: 'user', content: prompt }
            ],
            response_format: {
                type: 'json_schema',
                schema: parsedSchema
            }
        });

        if (result.success) {
            displayResult({
                method: 'generate',
                prompt: prompt,
                schema: parsedSchema,
                result: result.data
            }, false);
        } else {
            throw new Error(result.error?.message || 'Generation failed');
        }
    } catch (error) {
        displayResult(error.message || error.toString(), true);
    } finally {
        setButtonsDisabled(false);
    }
}

// Test generateText method
async function testGenerateText() {
    const { prompt } = getInputs();

    if (!prompt) {
        displayResult('Please enter a prompt', true);
        return;
    }

    try {
        setButtonsDisabled(true);
        displayResult('Generating text...', false);

        const result = await AppleIntelligence.generateText({
            messages: [
                { role: 'user', content: prompt }
            ]
        });

        if (result.success) {
            displayResult({
                method: 'generateText',
                prompt: prompt,
                result: result.content
            }, false);
        } else {
            throw new Error(result.error?.message || 'Generation failed');
        }
    } catch (error) {
        displayResult(error.message || error.toString(), true);
    } finally {
        setButtonsDisabled(false);
    }
}

// Test generateTextWithLanguage method
async function testGenerateTextWithLanguage() {
    const { prompt, language } = getInputs();

    if (!prompt) {
        displayResult('Please enter a prompt', true);
        return;
    }

    try {
        setButtonsDisabled(true);
        displayResult(`Generating text in ${language}...`, false);

        const result = await AppleIntelligence.generateTextWithLanguage({
            messages: [
                { role: 'user', content: prompt }
            ],
            language: language
        });

        if (result.success) {
            displayResult({
                method: 'generateTextWithLanguage',
                prompt: prompt,
                language: language,
                result: result.content
            }, false);
        } else {
            throw new Error(result.error?.message || 'Generation failed');
        }
    } catch (error) {
        displayResult(error.message || error.toString(), true);
    } finally {
        setButtonsDisabled(false);
    }
}

// Display ready message on load
document.addEventListener('DOMContentLoaded', async () => {
    console.log('Apple Intelligence Example App loaded');
    console.log('Plugin available:', typeof AppleIntelligence !== 'undefined');

    // Check Apple Intelligence availability
    const statusBadge = document.getElementById('status-badge');
    try {
        const result = await AppleIntelligence.checkAvailability();
        console.log('Availability result:', result);

        if (result && result.available) {
            statusBadge.textContent = '✓ Apple Intelligence Available';
            statusBadge.className = 'status-badge status-available';
        } else {
            statusBadge.textContent = '✗ Apple Intelligence Unavailable';
            statusBadge.className = 'status-badge status-unavailable';
            if (result && result.error) {
                console.log('Availability error:', result.error);
            }
        }
    } catch (error) {
        statusBadge.textContent = '✗ Apple Intelligence Unavailable';
        statusBadge.className = 'status-badge status-unavailable';
        console.error('Availability check failed:', error);
    }
});
