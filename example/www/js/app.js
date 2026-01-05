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
        language: document.getElementById('language').value,
        imageStyle: document.getElementById('imageStyle').value,
        sourceImageBase64: window.selectedSourceImageBase64 || null
    };
}

// Store selected source image as base64
window.selectedSourceImageBase64 = null;

// Preview source image when selected
function previewSourceImage(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function (e) {
        const base64Full = e.target.result;
        // Extract just the base64 data (remove data:image/...;base64, prefix)
        const base64Data = base64Full.split(',')[1];
        window.selectedSourceImageBase64 = base64Data;

        // Show preview
        const preview = document.getElementById('sourceImagePreview');
        const previewImg = document.getElementById('sourceImagePreviewImg');
        previewImg.src = base64Full;
        preview.style.display = 'block';
    };
    reader.readAsDataURL(file);
}

// Clear source image
function clearSourceImage() {
    window.selectedSourceImageBase64 = null;
    document.getElementById('sourceImage').value = '';
    document.getElementById('sourceImagePreview').style.display = 'none';
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

// Test generateImage method
async function testGenerateImage() {
    const { prompt, imageStyle, sourceImageBase64 } = getInputs();

    if (!prompt) {
        displayResult('Please enter a prompt', true);
        return;
    }

    // Clear previous images
    const imageResultDiv = document.getElementById('imageResult');
    imageResultDiv.innerHTML = '';
    imageResultDiv.style.display = 'none';

    try {
        setButtonsDisabled(true);
        const statusMsg = sourceImageBase64
            ? 'Generating image with source face...'
            : 'Generating image...';
        displayResult(statusMsg, false);

        const request = {
            prompt: prompt,
            style: imageStyle || undefined,
            count: 1
        };

        // Add source image if provided
        if (sourceImageBase64) {
            request.sourceImage = sourceImageBase64;
        }

        const result = await AppleIntelligence.generateImage(request);

        if (result.success && result.images) {
            displayResult({
                method: 'generateImage',
                prompt: prompt,
                style: imageStyle,
                hasSourceImage: !!sourceImageBase64,
                imageCount: result.images.length
            }, false);

            // Display images
            imageResultDiv.style.display = 'block';
            result.images.forEach(base64 => {
                const img = document.createElement('img');
                img.src = `data:image/jpeg;base64,${base64}`;
                img.style.maxWidth = '100%';
                img.style.borderRadius = '8px';
                img.style.marginTop = '10px';
                img.style.border = '1px solid #ddd';
                imageResultDiv.appendChild(img);
            });

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
