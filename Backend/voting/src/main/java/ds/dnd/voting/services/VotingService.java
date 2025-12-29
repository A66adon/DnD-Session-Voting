package ds.dnd.voting.services;

import ds.dnd.voting.dto.TimeSlotStatsDTO;
import ds.dnd.voting.dto.VoteResultDTO;
import ds.dnd.voting.dto.WeekResultDTO;
import ds.dnd.voting.model.TimeSlot;
import ds.dnd.voting.model.Vote;
import ds.dnd.voting.model.VotingWeek;
import ds.dnd.voting.repositories.TimeSlotRepository;
import ds.dnd.voting.repositories.VoteRepository;
import ds.dnd.voting.repositories.VotingWeekRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class VotingService {

    private final VotingWeekRepository votingWeekRepository;
    private final TimeSlotRepository timeSlotRepository;
    private final VoteRepository voteRepository;

    /**
     * Get the current active voting week
     */
    public VotingWeek getCurrentWeek() {
        return votingWeekRepository.findCurrentWeek(LocalDate.now())
                .orElseGet(this::createNewWeek);
    }

    /**
     * Get detailed results for a specific week including who voted for what
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getWeekResults(Long weekId) {
        VotingWeek week = votingWeekRepository.findById(weekId)
                .orElseThrow(() -> new RuntimeException("Week not found"));
        return buildWeekResultDTO(week);
    }

    /**
     * Get results for the current active week
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getCurrentWeekResults() {
        VotingWeek currentWeek = getCurrentWeek();
        return buildWeekResultDTO(currentWeek);
    }

    /**
     * Build a WeekResultDTO from a VotingWeek
     * Contains vote results, timeslot statistics, and winner determination
     */
    private WeekResultDTO buildWeekResultDTO(VotingWeek week) {
        List<Vote> votes = voteRepository.findVotesByVotingWeek(week.getId());

        // Create vote results showing who voted for what
        List<VoteResultDTO> voteResults = votes.stream()
                .map(vote -> new VoteResultDTO(
                        vote.getVoterName(),
                        vote.getTimeslots().stream()
                                .map(TimeSlot::getDatetime)
                                .sorted()
                                .collect(Collectors.toList()),
                        vote.getPreferredTimeSlot() != null ? vote.getPreferredTimeSlot().getDatetime() : null
                ))
                .collect(Collectors.toList());

        // Calculate statistics for each timeslot
        List<TimeSlotStatsDTO> timeSlotStats = week.getTimeSlots().stream()
                .map(timeSlot -> {
                    Long voteCount = timeSlotRepository.countVotesByTimeSlotId(timeSlot.getId());
                    Long preferredCount = timeSlotRepository.countPreferredVotesByTimeSlotId(timeSlot.getId());
                    // Weighted vote = regular votes + preferred votes (preferred counts double = 1 regular + 1 extra)
                    int weightedCount = voteCount.intValue() + preferredCount.intValue();
                    return new TimeSlotStatsDTO(
                            timeSlot.getId(),
                            timeSlot.getDatetime(),
                            voteCount.intValue(),
                            preferredCount.intValue(),
                            weightedCount,
                            false // Will be set later for winner
                    );
                })
                .sorted(Comparator.comparing(TimeSlotStatsDTO::getDatetime))
                .collect(Collectors.toList());

        // Determine winners based on weighted vote count (all timeslots with max votes win)
        int maxWeightedVotes = timeSlotStats.stream()
                .mapToInt(TimeSlotStatsDTO::getWeightedVoteCount)
                .max()
                .orElse(0);

        List<TimeSlotStatsDTO> winners = timeSlotStats.stream()
                .filter(ts -> ts.getWeightedVoteCount() == maxWeightedVotes && maxWeightedVotes > 0)
                .peek(ts -> ts.setWinner(true))
                .collect(Collectors.toList());

        WeekResultDTO result = new WeekResultDTO();
        result.setWeekId(week.getId());
        result.setDeadline(week.getDeadline());
        result.setTimeSlots(timeSlotStats);
        result.setVotes(voteResults);
        result.setWinnerTimeSlots(winners);

        return result;
    }

    /**
     * Get all past weeks with their results
     */
    @Transactional(readOnly = true)
    public List<WeekResultDTO> getAllPastWeeks() {
        List<VotingWeek> allWeeks = votingWeekRepository.findAllByOrderByDeadlineDesc();

        return allWeeks.stream()
                .filter(week -> week.getDeadline().isBefore(LocalDate.now()))
                .map(week -> getWeekResults(week.getId()))
                .collect(Collectors.toList());
    }

    /**
     * Get all weeks including current
     */
    @Transactional(readOnly = true)
    public List<WeekResultDTO> getAllWeeks() {
        List<VotingWeek> allWeeks = votingWeekRepository.findAllByOrderByDeadlineDesc();

        return allWeeks.stream()
                .map(week -> getWeekResults(week.getId()))
                .collect(Collectors.toList());
    }

    /**
     * Manually trigger a week reset (useful for testing)
     */
    @Transactional
    public VotingWeek resetWeek() {
        log.info("Manually triggering week reset");
        return createNewWeek();
    }
    /**
     * Scheduled task to reset the voting week every Monday at midnight
     */
    @Scheduled(cron = "0 0 0 * * MON", zone = "Europe/Berlin")
    @Transactional
    public void scheduledWeekReset() {
        log.info("Scheduled week reset triggered at {}", LocalDateTime.now());
        createNewWeek();
    }

    /**
     * Create a new voting week with fresh timeslots
     */
    @Transactional
    protected VotingWeek createNewWeek() {
        LocalDate today = LocalDate.now();

        // Calculate deadline: next Sunday
        LocalDate nextSunday = today.with(TemporalAdjusters.next(DayOfWeek.SUNDAY));

        // Create new voting week
        VotingWeek newWeek = new VotingWeek();
        newWeek.setDeadline(nextSunday);
        newWeek.setTimeSlots(new ArrayList<>());

        VotingWeek savedWeek = votingWeekRepository.save(newWeek);

        // Generate timeslots for the upcoming week (Monday to Sunday after deadline)
        List<TimeSlot> timeSlots = generateTimeSlots(nextSunday, savedWeek);
        timeSlotRepository.saveAll(timeSlots);

        savedWeek.getTimeSlots().addAll(timeSlots);

        log.info("Created new voting week with ID {} and deadline {}", savedWeek.getId(), nextSunday);

        return savedWeek;
    }

    /**
     * Generate timeslots for the week following the deadline
     * Creates slots for each day of the week at common gaming times
     */
    private List<TimeSlot> generateTimeSlots(LocalDate deadline, VotingWeek votingWeek) {
        List<TimeSlot> timeSlots = new ArrayList<>();

        // Start from Monday after the deadline
        LocalDate startDate = deadline.plusDays(1); // Monday after Sunday deadline

        // Generate slots for 7 days (Monday to Sunday)
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
            LocalDate date = startDate.plusDays(dayOffset);
            DayOfWeek dayOfWeek = date.getDayOfWeek();

            // All days get 18:00 slot
            timeSlots.add(new TimeSlot(LocalDateTime.of(date, LocalTime.of(18, 0)), votingWeek));

            // Saturday and Sunday also get 10:00 slot
            if (dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY) {
                timeSlots.add(new TimeSlot(LocalDateTime.of(date, LocalTime.of(10, 0)), votingWeek));
            }
        }

        log.info("Generated {} timeslots for week starting {}", timeSlots.size(), startDate);

        return timeSlots;
    }

    /**
     * Submit a vote for the current week
     * If the user has already voted, the existing vote will be updated
     */
    @Transactional
    public Vote submitVote(String voterName, List<Long> timeSlotIds, Long preferredTimeSlotId) {
        VotingWeek currentWeek = getCurrentWeek();

        // Verify all timeslots belong to current week
        List<TimeSlot> timeSlots = timeSlotRepository.findAllById(timeSlotIds);

        boolean allBelongToCurrentWeek = timeSlots.stream()
                .allMatch(ts -> ts.getVotingWeek().getId().equals(currentWeek.getId()));

        if (!allBelongToCurrentWeek) {
            throw new RuntimeException("Some timeslots do not belong to the current voting week");
        }

        // Handle preferred timeslot
        TimeSlot preferredTimeSlot = null;
        if (preferredTimeSlotId != null) {
            // Verify preferred timeslot is one of the selected timeslots
            if (!timeSlotIds.contains(preferredTimeSlotId)) {
                throw new RuntimeException("Preferred timeslot must be one of the selected timeslots");
            }
            preferredTimeSlot = timeSlotRepository.findById(preferredTimeSlotId)
                    .orElseThrow(() -> new RuntimeException("Preferred timeslot not found"));
        }

        // Check if user has already voted for this week
        Optional<Vote> existingVote = voteRepository.findByVoterNameAndVotingWeek(voterName, currentWeek.getId());

        Vote vote;
        if (existingVote.isPresent()) {
            // Update existing vote
            vote = existingVote.get();
            vote.getTimeslots().clear();
            vote.getTimeslots().addAll(timeSlots);
            vote.setPreferredTimeSlot(preferredTimeSlot);
            log.info("Updated vote for {} with {} timeslots, preferred: {}", voterName, timeSlotIds.size(), preferredTimeSlotId);
        } else {
            // Create new vote
            vote = new Vote(voterName, timeSlots, preferredTimeSlot);
            log.info("Created new vote for {} with {} timeslots, preferred: {}", voterName, timeSlotIds.size(), preferredTimeSlotId);
        }

        return voteRepository.save(vote);
    }

}
