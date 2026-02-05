# Participant "Question Not Found" Fix

## Issue Description
Participants were occasionally encountering a "Question not found" error when clicking the "Run" button in the participant page, even though the question was loaded and visible.

## Root Cause Analysis

### Primary Issues

1. **Backend Query Inconsistency**
   - The `/contest/run` endpoint was querying for questions using `WHERE q.question_id = %s`
   - Type mismatches between the frontend-sent ID (could be number or string) and database ID type
   - No detailed logging to help debug when questions weren't found

2. **Frontend Validation Gaps**
   - No validation to ensure `q.id` exists before sending the API request
   - Limited error handling for backend responses
   - No debug logging to track what data was being sent

3. **Potential Race Conditions**
   - Questions might not be fully loaded when user clicks "Run"
   - `currentQId` index might be out of sync with `questions` array

## Fixes Applied

### 1. Backend Improvements (`backend/routes/contest.py`)

#### Enhanced Question Lookup (Lines 348-421)
```python
# Added question_id to SELECT to verify what was found
query = """
    SELECT q.question_id, q.test_input, q.expected_output, q.test_cases, r.allowed_language
    FROM questions q
    LEFT JOIN rounds r ON q.round_id = r.round_id
    WHERE q.question_id = %s
"""

# Enhanced retry logic with logging
if not q_res:
    try:
        if str(question_id).isdigit():
            print(f"RUN CODE: Retrying with int conversion: {int(question_id)}")
            q_res = db_manager.execute_query(query, (int(question_id),))
        else:
            print(f"RUN CODE: Retrying with string: {str(question_id)}")
            q_res = db_manager.execute_query(query, (str(question_id),))
    except Exception as retry_err:
        print(f"RUN CODE: Retry failed: {retry_err}")
```

#### Debug Information on Failure
```python
if not q_res:
    # Enhanced error message with debugging info
    print(f"RUN CODE ERROR: Question ID {question_id} NOT FOUND in DB.")
    print(f"  - Contest ID: {contest_id}, Level: {level}")
    print(f"  - User ID: {user_id}")
    
    # Try to fetch available questions for this level to help debug
    debug_query = """
        SELECT q.question_id, q.question_title
        FROM questions q
        JOIN rounds r ON q.round_id = r.round_id
        WHERE r.contest_id = %s AND r.round_number = %s
        LIMIT 5
    """
    debug_res = db_manager.execute_query(debug_query, (contest_id, level))
    if debug_res:
        available_ids = [str(dq['question_id']) for dq in debug_res]
        print(f"  - Available question IDs for this level: {', '.join(available_ids)}")
    else:
        print(f"  - No questions found for contest {contest_id}, level {level}")
    
    return jsonify({
        'error': f'Question not found (ID: {question_id}). Please refresh the page and try again.',
        'success': False,
        'debug_info': {
            'requested_id': question_id,
            'contest_id': contest_id,
            'level': level
        }
    }), 404
```

### 2. Frontend Improvements (`frontend/participant.html`)

#### Enhanced Validation (Lines 1068-1120)
```javascript
async runCode() {
    if (this.isThrottled) return;
    const q = this.questions[this.currentQId];
    
    // Enhanced validation
    if (!q) {
        document.getElementById('console-output').innerHTML = 
            '<div class="error-msg">Error: Current question context invalid. Refresh page.</div>';
        return;
    }
    
    if (!q.id) {
        console.error('Question object missing ID:', q);
        document.getElementById('console-output').innerHTML = 
            '<div class="error-msg">Error: Question ID is missing. Please refresh the page.</div>';
        return;
    }
    
    // ... rest of code
}
```

#### Better Error Display
```javascript
if (res && res.error) {
    // Handle specific backend errors
    console.error('Backend error:', res.error, res.debug_info);
    let errorMsg = res.error;
    
    // Add helpful context if debug info is available
    if (res.debug_info) {
        errorMsg += `<br><small style="opacity: 0.8;">Requested ID: ${res.debug_info.requested_id}, Contest: ${res.debug_info.contest_id}, Level: ${res.debug_info.level}</small>`;
    }
    
    outDiv.innerHTML = `<div class="error-msg">${errorMsg}</div>`;
}
```

#### Enhanced Logging
```javascript
console.log('Sending run request with:', {
    question_id: questionId,
    contest_id: this.activeContestId,
    level: this.currentLevel,
    user_id: this.user.participant_id
});
```

## Key Improvements

✅ **Better Validation**: Frontend now validates question data before API calls  
✅ **Enhanced Logging**: Both frontend and backend log detailed information  
✅ **Debug Information**: Backend returns debug info to help troubleshoot  
✅ **Type Handling**: Improved handling of ID type conversions  
✅ **User-Friendly Errors**: Clear error messages with actionable advice  
✅ **Diagnostic Queries**: Backend queries available questions to help debug  

## Testing Recommendations

### Test Case 1: Normal Operation
1. Load a level with questions
2. Click "Run" on any question
3. **Expected**: Code runs successfully, no errors

### Test Case 2: Page Refresh During Run
1. Load a level
2. Start clicking "Run" rapidly
3. **Expected**: Throttling prevents multiple requests, no "question not found" errors

### Test Case 3: Invalid Question State
1. Manually corrupt question data in browser console: `Contest.questions[0].id = null`
2. Try to run code
3. **Expected**: Clear error message asking to refresh page

### Test Case 4: Backend Question Missing
1. Delete a question from database while participant is viewing it
2. Try to run code
3. **Expected**: Detailed error with debug info, suggestion to refresh

## Debugging Guide

If "Question not found" errors still occur:

1. **Check Backend Logs**
   - Look for `RUN CODE ERROR` messages
   - Check what question IDs are available vs. requested
   - Verify contest_id and level match

2. **Check Browser Console**
   - Look for "Sending run request with:" log
   - Verify question_id is not null/undefined
   - Check if questions array is populated

3. **Verify Database**
   ```sql
   -- Check if questions exist for the level
   SELECT q.question_id, q.question_title, r.round_number
   FROM questions q
   JOIN rounds r ON q.round_id = r.round_id
   WHERE r.contest_id = 1 AND r.round_number = 1;
   ```

4. **Check Question Loading**
   - Verify `/contest/questions?contest_id=X&level=Y` returns questions
   - Ensure each question has an `id` field

## Files Modified

1. **backend/routes/contest.py** (Lines 348-421)
   - Enhanced question lookup with better logging
   - Added debug query for available questions
   - Improved error responses with debug info

2. **frontend/participant.html** (Lines 1068-1120)
   - Added validation for question object and ID
   - Enhanced error handling and display
   - Added detailed console logging

## Deployment Notes

- **No database changes required**
- **No breaking changes**
- Backend and frontend changes are independent
- Can be deployed separately (backend first recommended)

## Related Issues

This fix also addresses:
- Race conditions when switching questions quickly
- Type mismatch errors between frontend and backend
- Lack of diagnostic information when errors occur
