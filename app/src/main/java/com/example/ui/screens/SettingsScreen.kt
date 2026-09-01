package com.example.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.AthleticBlue
import com.example.ui.theme.Slate400
import com.example.ui.theme.Slate900

@Composable
fun SettingsScreen(
    volumeBoost: Float,
    isBoostEnabled: Boolean,
    onBoostEnabledChange: (Boolean) -> Unit,
    onVolumeBoostChange: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.Settings,
                contentDescription = null,
                tint = AthleticBlue,
                modifier = Modifier.size(24.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Settings",
                fontWeight = FontWeight.Bold,
                fontSize = 20.sp,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        Text("Audio & preferences", fontSize = 12.sp, color = Slate400)
        Spacer(Modifier.height(16.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Slate900)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.VolumeUp,
                        contentDescription = null,
                        tint = AthleticBlue,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Volume Booster",
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp
                        )
                        Text(
                            if (isBoostEnabled) "Boost: ${
                                String.format(
                                    "%.0f%%",
                                    volumeBoost * 100
                                )
                            }" else "Disabled",
                            color = Slate400, fontSize = 12.sp
                        )
                    }
                    Switch(checked = isBoostEnabled, onCheckedChange = onBoostEnabledChange)
                }

                Spacer(Modifier.height(12.dp))

                Slider(
                    value = volumeBoost,
                    onValueChange = onVolumeBoostChange,
                    valueRange = 1f..3f,
                    steps = 3,
                    enabled = isBoostEnabled,
                    colors = SliderDefaults.colors(
                        thumbColor = AthleticBlue,
                        activeTrackColor = AthleticBlue,
                        inactiveTrackColor = Color.Gray.copy(alpha = 0.3f)
                    )
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text("100%", color = Slate400, fontSize = 10.sp)
                    Spacer(Modifier.weight(1f))
                    Text("300%", color = Slate400, fontSize = 10.sp)
                }
                if (isBoostEnabled && volumeBoost > 2f) {
                    Text(
                        "⚠ High boost may cause distortion on some devices",
                        color = Color(0xFFFF9800),
                        fontSize = 11.sp,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }
    }
}
